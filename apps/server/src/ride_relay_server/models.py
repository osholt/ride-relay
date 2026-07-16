from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Index,
    Integer,
    LargeBinary,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class Ride(Base):
    __tablename__ = "rides"

    id: Mapped[str] = mapped_column(String(128), primary_key=True)
    token_hash: Mapped[bytes] = mapped_column(LargeBinary(32), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    delete_after: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    events: Mapped[list[StoredEvent]] = relationship(
        back_populates="ride",
        cascade="all, delete-orphan",
    )
    replays: Mapped[list[IdempotencyReplay]] = relationship(
        back_populates="ride",
        cascade="all, delete-orphan",
    )


class StoredEvent(Base):
    __tablename__ = "ride_events"
    __table_args__ = (
        UniqueConstraint("ride_id", "event_id", name="uq_ride_event_identity"),
        Index("ix_ride_events_cursor", "ride_id", "sequence"),
        Index("ix_ride_events_expiry", "expires_at"),
    )

    sequence: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    ride_id: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("rides.id", ondelete="CASCADE"),
        nullable=False,
    )
    event_id: Mapped[str] = mapped_column(String(128), nullable=False)
    device_id: Mapped[str] = mapped_column(String(128), nullable=False)
    event_type: Mapped[str] = mapped_column(String(48), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    body_hash: Mapped[bytes] = mapped_column(LargeBinary(32), nullable=False)
    body_ciphertext: Mapped[bytes] = mapped_column(LargeBinary, nullable=False)

    ride: Mapped[Ride] = relationship(back_populates="events")


class IdempotencyReplay(Base):
    __tablename__ = "idempotency_replays"
    __table_args__ = (
        UniqueConstraint("ride_id", "idempotency_key", name="uq_ride_idempotency_key"),
        Index("ix_idempotency_replays_expiry", "expires_at"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    ride_id: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("rides.id", ondelete="CASCADE"),
        nullable=False,
    )
    idempotency_key: Mapped[str] = mapped_column(String(64), nullable=False)
    request_hash: Mapped[bytes] = mapped_column(LargeBinary(32), nullable=False)
    response_ciphertext: Mapped[bytes] = mapped_column(LargeBinary, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    ride: Mapped[Ride] = relationship(back_populates="replays")
