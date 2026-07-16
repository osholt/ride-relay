# Ride Relay

Ride Relay is an open-source, offline-first group motorcycle coordination app
for iOS and Android.

It is being designed for rural rides and the second-bike drop-off system. Every
important action is stored on the phone first. The target transport combines an
internet service with encrypted, store-and-forward exchange between nearby
phones when mobile coverage disappears.

> [!IMPORTANT]
> This repository is an early development preview, not a safety product. The
> local event journal and native platform bridges are implemented; actual
> cross-platform Bluetooth/Wi-Fi exchange, background reliability, location
> tracking, and off-route detection are still Phase 0/Phase 1 work. The app UI
> labels those capabilities accordingly.

## Current vertical slice

- Create a private ride or join with a six-character code.
- Resume the active ride after restarting the app.
- Store immutable, HMAC-tagged ride events in an idempotent SQLite journal.
- Record roles, manual marker sessions, unique marker passes, and priority
  quick messages.
- Generate and share a QR/deep-link invitation.
- Compile native Android and iOS capability bridges.
- Run analysis, tests, Android debug builds, and unsigned iOS builds in CI.

See [PLAN.md](./PLAN.md) for product requirements and delivery gates, and
[docs/architecture.md](./docs/architecture.md) for the implementation shape.

## Repository layout

```text
apps/mobile/                 Flutter application and native iOS/Android shells
docs/                        Architecture, field testing, and release notes
.github/workflows/mobile.yml Reproducible quality and mobile build pipeline
```

## Local development

The project currently pins CI to Flutter `3.44.6` and Dart `3.12.2`.

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

Android requires JDK 17 and a current Android SDK. iOS requires Xcode. No Apple
Developer signing identity is required for the development build:

```bash
flutter build ios --debug --no-codesign
```

Android debug builds use Android's standard debug certificate. Distribution
signing and all private key material are intentionally absent from the repo.

## Security and privacy

Do not use the current preview for real emergency coordination. See
[SECURITY.md](./SECURITY.md) for vulnerability reporting. Precise location data
and server retention are not implemented yet; they must pass the privacy and
deletion gates in the plan before public testing.

## License

[MIT](./LICENSE)
