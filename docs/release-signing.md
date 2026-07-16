# Build and signing policy

## Development phase

- Android CI produces a debug APK signed only with the runner's standard,
  ephemeral Android debug certificate.
- iOS CI uses `flutter build ios --debug --no-codesign` and uploads the unsigned
  `.app` directory as a build artifact.
- There are no release keystores, Apple certificates, provisioning profiles, or
  signing secrets in the repository or GitHub Actions configuration.

Unsigned iOS applications cannot normally be installed on a physical iPhone.
Simulator/device development through Xcode can use a developer's local account
later without changing the repository.

## Before external distribution

Create a separate release checklist covering bundle IDs, Apple Developer and
Google Play ownership, protected GitHub environments, short-lived CI secrets,
key rotation/recovery, notarised artifact provenance, and staged rollout. Never
reuse debug keys for release builds.
