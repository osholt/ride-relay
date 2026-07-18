# Navigation integration roadmap

Ride Relay's alpha can plan a road-following route, keep it locally, send a
documented destination handoff to Google Maps or Waze, and share a GPX file to
motorcycle navigation apps and devices. It does not yet claim a deep provider
integration, a vehicle projection surface, or a cross-app mini-map.

This document is the handoff boundary between the shipped alpha and the next
implementation PRs. Each implementation PR must link its issue with
`Closes #<issue>` only when the corresponding acceptance criteria are met.

## [#5: Motorcycle navigation handoffs and device exports](https://github.com/osholt/ride-relay/issues/5)

The next work is a provider capability registry and real-device handoff
evidence for Google Maps, Waze, Calimoto, MyRoute-app, Garmin and BMW
Motorrad Connected. The safe baseline remains standards-based GPX sharing;
documented links, SDKs or partner APIs can improve that handoff where a target
supports them. The UI must keep a receiver's limitations visible rather than
pretending that every target preserves the exact route.

## [#6: CarPlay and Android Auto ride companion](https://github.com/osholt/ride-relay/issues/6)

This is a separate native integration. It needs Apple entitlement approval for
CarPlay navigation and the Android for Cars navigation category/templates. The
first surface should be glanceable: next action, group separation, marker
state, priority alerts and recovery from the durable ride journal.

## [#7: Cross-app group mini-map companion](https://github.com/osholt/ride-relay/issues/7)

The existing in-app mini-map is the data and visual baseline. The platform
decision must come before product promises: iOS does not provide a general
purpose interactive map overlay through Picture in Picture, while Android
Picture-in-Picture needs a native lifecycle, policy and battery prototype.
CarPlay and Android Auto are the preferred approved projection surfaces.

## Delivery order

1. Validate official provider capabilities and ship the navigation handoff
   improvements from #5.
2. Prototype and obtain distribution eligibility for the projected vehicle
   surfaces in #6.
3. Make a platform decision and, only if supported, implement the companion
   mini-map in #7.

The existing alpha baseline is [PR #4](https://github.com/osholt/ride-relay/pull/4).
