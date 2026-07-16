# Architecture

## Current shape

The app is a Flutter client with thin Swift and Kotlin platform bridges. The
domain model does not depend on a particular network transport.

```text
UI -> RideController -> local event journal -> transport outboxes (next phase)
                            |
                            +-> materialised ride/marker status

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

The HMAC prevents accidental or unauthorised mutation inside one ride, but it
is not the final security design. Before external sync ships, each device will
have an asymmetric identity and signed events; sensitive payloads will also use
application-layer encryption.

## Planned transports

1. HTTPS/WebSocket service when internet is available.
2. Google Nearby Connections cluster transport on Android and iOS.
3. Store-and-forward relay: peers exchange missing priority events, not an
   unbounded raw location history.

The event journal is the source of truth. Neither a WebSocket nor a nearby
session is assumed to remain connected.

## Uncertainty is part of the model

The eventual UI states are `live`, `relayed`, `stale`, and `unknown`. A
timestamp or a successful API call alone must never be presented as proof that
another rider has received an event.

## Deliberately absent

- No production server or cloud credentials.
- No real location tracking or background modes.
- No Google Nearby SDK dependency yet.
- No distribution signing configuration.
- No claim that an app force-quit by the user can continue relaying on iOS.
