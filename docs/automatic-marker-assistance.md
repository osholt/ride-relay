# Automatic marker assistance development alpha

Marker assistance is deliberately advisory. It never changes a rider's role or
starts marker mode by itself. A suggestion opens a review action, followed by a
separate large **Start marking** confirmation. Moving away or dismissing the
suggestion starts a cooldown.

## Suggestion contract

`MarkerSuggestionDetector` is a deterministic state machine. A suggestion needs
all of the following:

- an imported route with an explicit waypoint or a geometric turn of at least
  35 degrees;
- a recent, accurate local position within 35 m of that decision point;
- local speed below 0.8 m/s for 12 seconds, with 1.8 m/s exit hysteresis;
- at least one recent group rider at least 45 m farther along the route who is
  within 80 m of the route and moving at least 3 m/s or has advanced at least
  20 m between observations. Riders already in marker mode are excluded.

The defaults are conservative starting assumptions, not validated safety
thresholds. A rider dismissal cools suggestions down for five minutes. Movement
cancellation cools them down for two minutes. Active marker mode suppresses
suggestions completely.

For multi-path GPX files, the development alpha monitors the longest continuous
path rather than creating synthetic junctions between disconnected segments.

## Verified pass counting

`MarkerPassDetector` fixes the marker position when marker mode starts. A rider
must first be observed outside 60 m and then inside 30 m. The fix must be no more
than 20 seconds old, have accuracy of 40 m or better, and carry a location event
whose HMAC verifies for the ride and whose device identifier matches the rider.
Initially-near, stale, inaccurate, unauthenticated, and duplicate fixes do not
count.

This is group-secret authentication, not cryptographic proof of an individual
device identity. Per-member keys and revocation remain production security gates.

The resulting `markerPass` event records the marker session, location evidence
event, rider role and observation time. A verified Tail End Charlie passage is
shown as a prompt to finish when safe; it does not automatically end marker mode.

## Statistics and relay ordering

`MarkerStatistics` reduces append-only ride events into per-device,
per-marker-session summaries. Session identifiers prevent interleaved relay
events from different markers absorbing or closing each other. The local
dashboard shows local-device marking time, sessions, verified passes and verified
TEC passages. `rideEnded` persists the summary and keeps the durable ride session
available for final relay recovery for up to 24 hours. The rider can remove it
immediately; after that window the local session, group secret and event journal
are deleted automatically.

## Field-calibration gates

Before enabling the feature outside development alpha, complete controlled field
tests covering urban GPS multipath, staggered junctions, roundabouts, U-turns,
parallel roads, stopped traffic, very small groups, delayed relay events and TEC
role changes. Measure false suggestions, missed suggestions, false pass counts,
missed passes and time-to-cancel. Threshold changes must be based on those data.

The module uses only foreground positions already requested by the rider. It does
not start location services, declare background tracking, replace visual rider
checks, or provide an emergency-service function.
