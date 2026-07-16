# Ride Relay server

The online store-and-forward service for Ride Relay. It implements the mobile
`events:sync` contract with automatic first-use ride claiming, encrypted event
storage, authenticated opaque cursors, idempotent batches, bounded pagination,
rate limits and automatic retention.

The service deliberately stores only a hash of the ride bearer credential. It
never receives the invitation secret and therefore leaves final event-HMAC
verification to receiving phones.

## Development

```bash
uv sync --extra dev
uv run alembic upgrade head
uv run ride-relay-server
uv run pytest
uv run ruff check .
uv run ruff format --check .
```

Configuration is documented in `.env.example`. Production requires PostgreSQL,
two independently generated 32-byte keys, TLS termination and a scheduled
`ride-relay-cleanup` invocation.
