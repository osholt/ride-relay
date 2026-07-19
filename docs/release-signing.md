# Build and signing policy

## Development phase

- Android CI produces a debug APK signed only with the runner's standard,
  ephemeral Android debug certificate.
- iOS CI uses `flutter build ios --debug --no-codesign` and uploads the unsigned
  `.app` directory as a build artifact.
- There are no release keystores, Apple certificates, provisioning profiles, or
  signing secrets stored in the repository. The manual TestFlight workflow only
  reads signing material from GitHub Actions secrets once those are configured.

Unsigned iOS applications cannot normally be installed on a physical iPhone.
Simulator/device development through Xcode can use a developer's local account
later without changing the repository.

## TestFlight beta distribution

The iOS target uses bundle ID `app.tailendcharlie`, automatic signing, and the
Apple Developer team configured in Xcode. `ios/ExportOptions-TestFlight.plist`
produces an App Store Connect IPA. The `TestFlight` GitHub workflow is manual
only, so normal commits and pull requests never send a build to Apple.

The app previously shipped internal TestFlight builds under bundle ID
`me.osholt.rideRelay`. That identifier is retired - Apple never allows a bundle
ID to be changed on an existing App Store Connect app record, so matching the
Android `app.tailendcharlie` rename meant registering a new App ID and starting
a new app record rather than editing the old one. Existing internal testers
need re-adding under the new record; TestFlight build history does not carry
over.

Before the first upload under the new identifier, register the `app.tailendcharlie`
App ID in the Apple Developer portal; sign in to App Store Connect as an Account
Holder, Admin, App Manager, or Developer; create the `Tail End Charlie` iOS app
record using that bundle ID; and accept any outstanding agreements. Create a
least-privilege App Store Connect API key and an App Store provisioning profile
(the profile name must match the `provisioningProfiles` entry in
`ios/ExportOptions-TestFlight.plist`), then add these repository secrets:

- `APPLE_DISTRIBUTION_CERTIFICATE_BASE64` and
  `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD` — an Apple Distribution `.p12`.
- `APPLE_APPSTORE_PROFILE_BASE64` — the App Store provisioning profile.
- `APPLE_CI_KEYCHAIN_PASSWORD` — a random, dedicated temporary-keychain
  password.
- `APPSTORE_CONNECT_API_KEY_ID`, `APPSTORE_CONNECT_API_ISSUER_ID`, and
  `APPSTORE_CONNECT_API_PRIVATE_KEY_BASE64` — the App Store Connect API key.

Run **TestFlight** from the Actions tab and provide a unique build number if the
default GitHub run number has already been uploaded. Apple processes the upload
before it appears under the app's TestFlight tab. Start with internal testers;
external TestFlight testing and App Store release require their own review,
privacy, age-rating, and export-compliance steps.

## Before public App Store distribution

Create a separate release checklist covering bundle IDs, Apple Developer and
Google Play ownership, protected GitHub environments, short-lived CI secrets,
key rotation/recovery, notarised artifact provenance, and staged rollout. Never
reuse debug keys for release builds.
