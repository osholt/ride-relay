# Architecture

## Current shape

The app is a Flutter client with thin Swift and Kotlin platform bridges. The
domain model does not depend on a particular network transport.

```text
UI -> RideController -> local event journal
                            |
                            +-> NearbyRelayController -> durable relay queue
                                                           |
                                                           +-> PeerTransport
                            |
                            +-> InternetRelayController -> bounded HTTPS sync
                                                           -> opaque cursor

Flutter -> method channel -> Swift / Kotlin nearby transport adapters
```

Every state-changing user action is converted into a `RideEvent` and appended
to SQLite before it is considered accepted. Event IDs are primary keys, so a
relay may safely deliver the same event repeatedly. Read models can be rebuilt
from the journal.

## Event envelope

The initial envelope contains:

- schema version;
- globally unique event ID;
- ride and device IDs;
- type, priority, creation and expiry times;
- typed JSON payload;
- ride-secret HMAC; and
- local acknowledgement state.

New events use one canonical ride-secret HMAC body. Verification retains
read-compatibility with the earlier development-alpha body. Downloaded internet
events are verified before storage. The local `acknowledged` delivery flag is
intentionally not signed because each phone changes it after successful relay.
This group HMAC is not the final security design: device identity, key rotation,
and application-layer encryption remain production gates.

## Relay transport

The transport-neutral relay engine implements bounded, HMAC-authenticated,
ACK-driven store-and-forward exchange. Its native adapter links Google Nearby
Connections cluster transport on Android and iOS. Physical cross-platform
offline validation is still a release gate; see `nearby-relay.md`.

The HTTPS worker batches pending journal events and pulls missing events by
opaque cursor. It is disabled unless an HTTPS endpoint is configured. The
reference FastAPI/PostgreSQL relay, contract, retention, and trust boundaries
are documented in `internet-relay.md` and `server-architecture.md`.
Retries are automatic, bounded, and jittered. Request, response, event, and
timeout limits are enforced on the client.

Server acknowledgement and nearby delivery are separate concerns. The journal
acknowledgement currently represents server acceptance; nearby scans every ride
event and relies on its own durable queue for per-peer ACK and deduplication.
This allows an internet-connected phone to carry downloaded events back into an
offline cluster.

The event journal is the source of truth. Neither a WebSocket nor a nearby
session is assumed to remain connected.

## Ride lifecycle

A newly created ride is `open`, not live. Riders may join and appear in the
event-derived roster, but the client does not persist, publish, replay or draw
location fixes, route progress, route-deviation state, marker activity or rider
traces until a signed `rideStarted` event is accepted.

Only a locally active lead can create `rideStarted`, and the UI requires a
confirmation. Replayers order signed events by `createdAt` and then event ID,
rebuild each rider's latest role, and choose the first start authored by a lead.
That makes duplicate taps, offline delivery, restart and a pre-start role
handover deterministic. Late joiners download the same journal and enter the
started state without creating another start event. Ride summaries and GPX
traces use the accepted event time as their lower bound.

Pre-start presence is deliberately roster-only: no coarse coordinate is sent.
This is still a group-HMAC trust model, so production-grade per-device leader
authorization remains part of the device-identity/key-rotation release gate.

## Uncertainty is part of the model

The eventual UI states are `live`, `relayed`, `stale`, and `unknown`. A
timestamp or a successful API call alone must never be presented as proof that
another rider has received an event.

## Deliberately absent

- No public deployment, production cloud credentials, or basemap dataset/style.
- No background location tracking or background relay modes; foreground
  positioning is implemented and requires explicit permission.
- No claim that the linked Nearby SDK has passed the physical-device matrix.
- No distribution signing configuration.
- No claim that an app force-quit by the user can continue relaying on iOS.
