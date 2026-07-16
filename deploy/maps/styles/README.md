# MapLibre styles

Place the dataset-matched MapLibre style JSON, sprites and glyphs here. A style
named `ride-relay.json` is exposed as:

```text
https://<RIDE_RELAY_DOMAIN>/maps/styles/ride-relay.json
```

Use relative source URLs such as `../tiles/basemap/{z}/{x}/{y}` so the same
style works through Caddy. Do not deploy a style copied from a provider unless
its licence permits redistribution and offline region downloads.
