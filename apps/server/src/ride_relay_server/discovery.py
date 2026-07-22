from __future__ import annotations

import json
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from .crypto import sha256
from .models import (
    DiscoveryFeature,
    DiscoveryModerationEvent,
    DiscoverySuggestion,
)
from .schemas import DiscoveryModerationRequest, DiscoverySuggestionRequest
from .service import RelayServiceError

PUBLIC_WARNING = (
    "Discovery highlights are descriptive and are not safety endorsements. "
    "Check current access, closures, weather and road conditions."
)


def create_suggestion(
    session: Session,
    payload: DiscoverySuggestionRequest,
    *,
    now: datetime | None = None,
) -> DiscoverySuggestion:
    now = now or datetime.now(UTC)
    canonical = json.dumps(
        payload.model_dump(mode="json"),
        sort_keys=True,
        separators=(",", ":"),
    ).encode()
    request_hash = sha256(canonical)
    existing = session.scalar(
        select(DiscoverySuggestion).where(
            DiscoverySuggestion.client_submission_id == payload.clientSubmissionId
        )
    )
    if existing is not None:
        if existing.request_hash != request_hash:
            raise RelayServiceError(409, "Submission identifier already used")
        return existing

    suggestion = DiscoverySuggestion(
        id=str(uuid.uuid4()),
        client_submission_id=payload.clientSubmissionId,
        request_hash=request_hash,
        category=payload.category,
        action=payload.action,
        target_feature_id=payload.targetFeatureId,
        name=payload.name.strip(),
        reason=payload.reason.strip(),
        evidence_url=str(payload.evidenceUrl) if payload.evidenceUrl else None,
        geometry_json=payload.geometry.model_dump(mode="json"),
        status="pending",
        submitted_at=now,
        updated_at=now,
    )
    session.add(suggestion)
    session.commit()
    return suggestion


def list_suggestions(
    session: Session,
    *,
    status: str,
    limit: int = 100,
) -> list[DiscoverySuggestion]:
    return list(
        session.scalars(
            select(DiscoverySuggestion)
            .where(DiscoverySuggestion.status == status)
            .order_by(DiscoverySuggestion.submitted_at)
            .limit(limit)
        )
    )


def purge_expired_private_suggestions(
    session: Session,
    *,
    retention_days: int,
    now: datetime | None = None,
) -> int:
    cutoff = (now or datetime.now(UTC)) - timedelta(days=retention_days)
    result = session.execute(
        delete(DiscoverySuggestion).where(
            DiscoverySuggestion.status.in_({"rejected", "superseded"}),
            DiscoverySuggestion.updated_at < cutoff,
        )
    )
    session.commit()
    return result.rowcount or 0


def moderate_suggestion(
    session: Session,
    suggestion_id: str,
    request: DiscoveryModerationRequest,
    *,
    reviewer: str,
    now: datetime | None = None,
) -> DiscoverySuggestion:
    now = now or datetime.now(UTC)
    suggestion = session.get(DiscoverySuggestion, suggestion_id)
    if suggestion is None:
        raise RelayServiceError(404, "Suggestion not found")
    if suggestion.status not in {"pending", "changes_requested"}:
        raise RelayServiceError(409, "Suggestion has already been moderated")

    status = {
        "approve": "approved",
        "reject": "rejected",
        "request_changes": "changes_requested",
        "supersede": "superseded",
    }[request.action]
    suggestion.status = status
    suggestion.updated_at = now
    suggestion.reviewed_at = now
    suggestion.reviewer = reviewer
    suggestion.moderation_reason = request.reason.strip()
    if request.action == "approve":
        suggestion.published_feature_id = _publish_approved_revision(
            session,
            suggestion,
            now,
        )
    session.add(
        DiscoveryModerationEvent(
            suggestion_id=suggestion.id,
            action=request.action,
            actor=reviewer,
            reason=request.reason.strip(),
            created_at=now,
        )
    )
    session.commit()
    return suggestion


def public_feature_collection(
    session: Session,
    *,
    west: float,
    south: float,
    east: float,
    north: float,
    categories: set[str],
) -> dict:
    features = session.scalars(
        select(DiscoveryFeature)
        .where(
            DiscoveryFeature.status == "active",
            DiscoveryFeature.category.in_(categories),
        )
        .limit(1000)
    )
    return {
        "type": "FeatureCollection",
        "features": [
            _feature_geojson(feature)
            for feature in features
            if _intersects_bounds(
                feature.geometry_json,
                west=west,
                south=south,
                east=east,
                north=north,
            )
        ],
    }


def suggestion_json(suggestion: DiscoverySuggestion, *, include_private: bool) -> dict:
    result = {
        "id": suggestion.id,
        "clientSubmissionId": suggestion.client_submission_id,
        "status": suggestion.status,
        "submittedAt": suggestion.submitted_at.isoformat(),
        "updatedAt": suggestion.updated_at.isoformat(),
        "publishedFeatureId": suggestion.published_feature_id,
    }
    if include_private:
        result.update(
            {
                "category": suggestion.category,
                "action": suggestion.action,
                "targetFeatureId": suggestion.target_feature_id,
                "name": suggestion.name,
                "reason": suggestion.reason,
                "evidenceUrl": suggestion.evidence_url,
                "geometry": suggestion.geometry_json,
                "reviewedAt": suggestion.reviewed_at.isoformat()
                if suggestion.reviewed_at
                else None,
                "reviewer": suggestion.reviewer,
                "moderationReason": suggestion.moderation_reason,
                "auditTrail": [
                    {
                        "action": event.action,
                        "actor": event.actor,
                        "reason": event.reason,
                        "createdAt": event.created_at.isoformat(),
                    }
                    for event in suggestion.audit_events
                ],
            }
        )
    return result


def _publish_approved_revision(
    session: Session,
    suggestion: DiscoverySuggestion,
    now: datetime,
) -> str:
    feature_id = (
        suggestion.target_feature_id
        if suggestion.action in {"correct", "remove"}
        else f"tec-community-{suggestion.id}"
    )
    if feature_id is None:  # defended by schema, retained for service callers
        raise RelayServiceError(400, "Revision target required")
    feature = session.get(DiscoveryFeature, feature_id)
    if feature is None:
        feature = DiscoveryFeature(
            id=feature_id,
            category=suggestion.category,
            name=suggestion.name,
            geometry_json=suggestion.geometry_json,
            status="active",
            confidence="community-reviewed",
            source_name="Tail End Charlie approved submission",
            source_feature_id=suggestion.id,
            source_url=suggestion.evidence_url,
            warning=PUBLIC_WARNING,
            approved_revision_id=suggestion.id,
            last_verified_at=now,
        )
        session.add(feature)
    else:
        feature.category = suggestion.category
        feature.name = suggestion.name
        feature.geometry_json = suggestion.geometry_json
        feature.source_feature_id = suggestion.id
        feature.source_url = suggestion.evidence_url
        feature.approved_revision_id = suggestion.id
        feature.last_verified_at = now
    feature.status = "removed" if suggestion.action == "remove" else "active"
    return feature_id


def _feature_geojson(feature: DiscoveryFeature) -> dict:
    return {
        "type": "Feature",
        "properties": {
            "id": feature.id,
            "category": feature.category,
            "name": feature.name,
            "confidence": feature.confidence,
            "sourceName": feature.source_name,
            "sourceFeatureId": feature.source_feature_id,
            "sourceUrl": feature.source_url,
            "lastVerified": feature.last_verified_at.date().isoformat(),
            "moderationStatus": "approved",
            "approvedRevisionId": feature.approved_revision_id,
            "warning": feature.warning,
        },
        "geometry": feature.geometry_json,
    }


def _intersects_bounds(
    geometry: dict,
    *,
    west: float,
    south: float,
    east: float,
    north: float,
) -> bool:
    coordinates = geometry.get("coordinates", [])
    points = [coordinates] if geometry.get("type") == "Point" else coordinates
    return any(
        isinstance(point, list)
        and len(point) == 2
        and west <= point[0] <= east
        and south <= point[1] <= north
        for point in points
    )
