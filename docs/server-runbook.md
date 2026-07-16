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
