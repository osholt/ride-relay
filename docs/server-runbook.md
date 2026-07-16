# Server deployment runbook

## Prepare

Use a host with Docker Compose, a public DNS record, inbound TCP 80/443 and UDP
443, persistent storage, monitoring, and backups. Never expose port 8080 or the
PostgreSQL port publicly; trusting forwarded IP headers is safe only behind the
included Caddy network boundary.

```bash
cp deploy/.env.example deploy/.env
python3 -c 'import base64,secrets; print(base64.urlsafe_b64encode(secrets.token_bytes(32)).decode().rstrip("="))'
python3 -c 'import base64,secrets; print(base64.urlsafe_b64encode(secrets.token_bytes(32)).decode().rstrip("="))'
```

Put two different generated values and a long random PostgreSQL password in
`deploy/.env`. Keep this file out of Git and in the host's secret backup.
Set `RIDE_RELAY_MAXIMUM_ACTIVE_RIDES` from the encrypted-volume capacity and
expected field-test population; the default is 100. The event and replay byte
quotas in the same file should also be kept within the available volume.

## Deploy and verify

```bash
docker compose --env-file deploy/.env -f deploy/compose.yaml config
docker compose --env-file deploy/.env -f deploy/compose.yaml up -d --build
curl --fail https://relay.example.com/health/live
docker compose --env-file deploy/.env -f deploy/compose.yaml exec -T server \
  python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health/ready')"
```

Caddy obtains and renews TLS automatically. Compile
`https://relay.example.com/api` into the field-test app only after both health
checks pass. Run a two-phone ride claim/sync test before a field ride.

For maps, add a licence-approved archive and matching style as described in
[maps-and-gpx.md](./maps-and-gpx.md), then add `--profile maps` to the Compose
command and verify the style plus representative tiles.

## Tailnet-only field-test host

For a private field test, the override runs a Tailscale sidecar with its own
persisted tailnet identity and proxies to the API over the private Docker
network. No API port is published on the Docker host. Tailscale Serve terminates
HTTPS and Funnel remains disabled. Do not start the public Caddy service in this
mode:

```bash
cp deploy/.env.example deploy/.env.tailnet
# Set RIDE_RELAY_DOMAIN=ride-relay.<tailnet>.ts.net, the database password,
# and both random keys. Optionally set RIDE_RELAY_TAILSCALE_HOSTNAME.
# Set TS_AUTHKEY to a one-off key for unattended first-time registration.
docker compose --project-name ride-relay-tailnet \
  --env-file deploy/.env.tailnet \
  --file deploy/compose.yaml \
  --file deploy/compose.tailnet.yaml \
  up -d --build db tailscale server cleanup
```

If no auth key is supplied, follow the one-time URL printed by `docker compose
logs tailscale`; the `tailscale-state` volume preserves the resulting identity
across restarts and container recreation. Verify it with:

```bash
docker compose --project-name ride-relay-tailnet \
  --env-file deploy/.env.tailnet \
  --file deploy/compose.yaml \
  --file deploy/compose.tailnet.yaml \
  exec -T tailscale tailscale status
curl --fail https://ride-relay.<tailnet>.ts.net/health/ready
```

Compile the field-test client with
`RIDE_RELAY_API_BASE_URL=https://ride-relay.<tailnet>.ts.net/api`. Tailscale ACLs
determine which tailnet members can reach the HTTPS address. Readiness and
metrics are tailnet-visible in this temporary topology, so use the public Caddy
topology before internet exposure.

## Operations

- Alert if readiness fails, 5xx rises, sync latency grows, PostgreSQL storage
  grows unexpectedly, or cleanup stops logging hourly completion.
- Back up with `pg_dump -Fc` to encrypted off-host storage and test restore.
- Upgrade by backing up, pulling the tagged commit, running `docker compose
  build`, and applying the Alembic migration through server startup.
- Rotate the cursor key only when invalidating all saved mobile cursors is
  acceptable; clients recover with a fresh cursor after clearing local state.
- Do not rotate the data-encryption key without a decrypt/re-encrypt migration;
  old events and idempotency replays otherwise become unreadable.
- Treat logs as sensitive even though the app does not intentionally log event
  bodies or bearer credentials.

## Rollback

Restore the previous image/commit only when its database migration is compatible.
If not, stop writes, restore the pre-deploy database backup, then restore the
previous containers. Mobile clients keep retrying bounded requests while the
service is unavailable.
