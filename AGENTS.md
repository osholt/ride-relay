# Tail End Charlie — Codex Instructions

<!-- Current work and verified handoff -->
@docs/next-agent-handoff.md

## Project overview

Tail End Charlie is an offline-first group motorcycle coordination system. The
repository contains a Flutter mobile client, native Swift/Kotlin transport
bridges, a FastAPI/PostgreSQL relay, deployment configuration, and a static
Cloudflare Pages website.

## Entry points

- `PLAN.md` — product scope, acceptance criteria, and release gates.
- `apps/mobile/` — Flutter app and native iOS/Android shells.
- `apps/server/` — relay service and migrations.
- `apps/website/` — static production website.
- `docs/` — architecture, field-test, navigation, release, and runbook detail.

## Narrow verification

```bash
cd apps/mobile
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

```bash
cd apps/server
uv sync --frozen --extra dev
uv run ruff format --check .
uv run ruff check .
uv run pytest
```

## Project rules

- Preserve offline-first event-journal and transport-neutral domain boundaries.
- Do not claim Nearby, background, battery, navigation-device, CarPlay, Android
  Auto, or PiP support without the physical/platform evidence required in the
  corresponding issue and field-test documentation.
- Use only documented provider integrations; GPX sharing remains the safe
  fallback when an official deep integration is unavailable.
- Never commit signing keys, service-account JSON, passwords, or API tokens.
- Treat app identifiers and signing keys as release decisions. Ask before
  creating a store app, changing a permanent identifier, or generating an
  upload key without an agreed encrypted backup.
