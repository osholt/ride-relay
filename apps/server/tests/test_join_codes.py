from __future__ import annotations

from fastapi.testclient import TestClient
from sqlalchemy import select

from ride_relay_server.app import create_app
from ride_relay_server.models import RideJoinCode

from .conftest import ride_token

SECRET = "0123456789abcdef0123456789abcdef"


def _register(client, *, code: str = "123456", ride_id: str = "ride-join-code"):
    return client.put(
        f"/api/v1/join-codes/{code}",
        json={"rideId": ride_id, "inviteSecret": SECRET},
        headers={"authorization": f"Bearer {ride_token(ride_id, SECRET)}"},
    )


def test_register_and_resolve_six_digit_ride_code(client, settings) -> None:
    registered = _register(client)
    assert registered.status_code == 204

    resolved = client.get("/api/v1/join-codes/123456")
    assert resolved.status_code == 200
    assert resolved.json() == {
        "rideId": "ride-join-code",
        "rideCode": "123456",
        "inviteSecret": SECRET,
    }

    factory = client.app.state.session_factory
    with factory() as session:
        stored = session.scalar(select(RideJoinCode).where(RideJoinCode.code == "123456"))
        assert stored is not None
        assert SECRET.encode() not in stored.secret_ciphertext


def test_registering_the_same_ride_code_is_idempotent(client) -> None:
    assert _register(client).status_code == 204
    assert _register(client).status_code == 204


def test_ride_code_cannot_be_claimed_by_another_ride(client) -> None:
    assert _register(client).status_code == 204
    response = _register(client, ride_id="another-ride")
    assert response.status_code == 409
    assert response.json() == {"error": "Ride code is already in use"}


def test_ride_code_registration_requires_matching_credential(client) -> None:
    response = client.put(
        "/api/v1/join-codes/123456",
        json={"rideId": "ride-join-code", "inviteSecret": SECRET},
        headers={"authorization": f"Bearer {ride_token('ride-join-code', 'wrong-secret-value')}"},
    )
    assert response.status_code == 403


def test_ride_code_lookup_is_numeric_and_rate_limited(settings) -> None:
    limited = settings.model_copy(update={"join_code_lookup_rate_limit_requests": 1})

    with TestClient(create_app(limited)) as client:
        assert _register(client).status_code == 204
        invalid = client.get("/api/v1/join-codes/12345x")
        assert client.get("/api/v1/join-codes/123456").status_code == 200
        rejected = client.get("/api/v1/join-codes/123456")

    assert invalid.status_code == 400
    assert rejected.status_code == 429
