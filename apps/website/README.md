# Tail End Charlie website

This is the static marketing site and browser ride planner for
`tailendcharlie.app`.

The site uses no analytics, web fonts, cookies, or server-side user data.
`planner.html` uses pinned MapLibre GL JS, OpenFreeMap tiles, the same OSRM
routing service as the mobile app, and user-triggered Nominatim searches. Ride
names and generated GPX files stay in the browser; route coordinates and place
queries go only to those documented providers. Cloudflare Pages is connected
directly to this repository and publishes the site automatically from `main`.

Run the planner unit tests with:

```bash
node --test planner-core.test.mjs
```
