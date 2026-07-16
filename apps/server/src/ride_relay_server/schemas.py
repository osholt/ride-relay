from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field


class SyncRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    protocolVersion: Literal[1]
    deviceId: str = Field(min_length=1, max_length=128)
    cursor: str | None = Field(default=None, max_length=512)
    events: list[dict[str, Any]]


class SyncResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    protocolVersion: Literal[1] = 1
    cursor: str
    acceptedEventIds: list[str]
    events: list[dict[str, Any]]
