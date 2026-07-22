# Tail End Charlie website

This is the static marketing site and browser ride planner for
`tailendcharlie.app`.

The site uses no analytics, web fonts, cookies, or server-side user data.
`planner.html` uses pinned MapLibre GL JS, OpenFreeMap tiles, OSRM road routing,
Valhalla motorcycle routing for motorway avoidance, and user-triggered
Nominatim searches. It includes a small local starter catalogue of biker cafés
and links to the complete Bike + Brew venue directory. Ride names and generated
GPX files stay in the browser; route coordinates and place queries go only to
the documented providers. Cloudflare Pages is connected directly to this
repository and publishes the site automatically from `main`.

Run the planner unit tests with:

```bash
node --test *.test.mjs
```
