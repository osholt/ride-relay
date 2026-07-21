# Android internal testing

Tail End Charlie's Android beta channel is Google Play's `internal` testing
track, fed by a manual `Android internal testing` GitHub Actions workflow -
the Android equivalent of [the TestFlight workflow](./server-runbook.md).

## One-time external setup

These steps happen outside this repository and are release gates for the
first upload:

1. **Confirm the package name.** It's `app.tailendcharlie` - the Play Store
   listing must be created under this exact package, since it cannot change
   after the first upload.
2. **Create the app in Google Play Console** and enrol it in
   [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756).
   Google then holds the final signing key; the workflow only ever handles
   the *upload* key below.
3. **Generate a dedicated upload keystore** (never commit it):
   ```bash
   keytool -genkeypair -v -keystore upload-keystore.jks \
     -alias tailendcharlie-upload -keyalg RSA -keysize 2048 -validity 10000
   ```
   Back this file up somewhere durable and encrypted - if it's lost before
   Play App Signing has a copy, Google support can reissue an upload key, but
   it's a real disruption to avoid.
4. **Create a least-privilege Google Play service account** (Play Console ->
   Setup -> API access), download its JSON key, and grant it only the
   permissions needed to manage releases on the internal track.
5. **Create the protected `android-internal` GitHub environment** (Settings
   -> Environments) with these repository secrets:
   - `ANDROID_KEYSTORE_BASE64` - `base64 -i upload-keystore.jks | pbcopy`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
   - `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` - the full JSON key content
6. **Add the initial tester list** in Play Console's internal testing track
   and publish the opt-in URL to testers.
7. **Run the workflow once and verify**: install through the opt-in link on
   a physical Android phone, not just the emulator.

## Repository behaviour

`apps/mobile/android/app/build.gradle.kts` reads signing material from
`android/key.properties` (git-ignored, absent on every local checkout).
Without it, release builds silently fall back to the debug key - a plain
`flutter build appbundle --release` locally never fails and never touches
real signing material. The GitHub Actions workflow is the only place
`key.properties` gets created, from the secrets above, in `$RUNNER_TEMP`.

Version codes come from `inputs.build_number` or, by default,
`github.run_number` - the same monotonic-by-construction source the
TestFlight workflow uses for iOS build numbers, so they never collide or go
backwards.

## Triggering a beta

```bash
gh workflow run "Android internal testing" --ref <branch>
```

Needs the `RIDE_RELAY_API_BASE_URL` repository variable set first (see
[server-runbook.md](./server-runbook.md)) - the build fails clearly if it's
missing, the same as TestFlight.

## Local fallbacks

Two options exist for a quick check without waiting on a Play Store upload
and its review/propagation delay:

- **Android Emulator**: `flutter run` against any AVD is the fastest
  iteration loop and needs no signing or Play Console access at all.
- **Firebase App Distribution**: a lighter-weight alternative to Play
  internal testing when testers just need a signed build fast (no Play
  Console review, install links usually work within minutes). Not wired up
  in this repository - `flutter build apk --release` plus the
  [Firebase CLI's `appdistribution:distribute`](https://firebase.google.com/docs/app-distribution/android/distribute-cli)
  command is the manual path if this becomes useful before Play internal
  testing is fully live.
