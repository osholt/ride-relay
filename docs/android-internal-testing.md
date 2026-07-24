# Android internal testing

Tail End Charlie's immediate Android beta channel is Google Play's `internal`
testing track, fed by a manual `Android internal testing` GitHub Actions workflow -
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
4. **Create a least-privilege Google Play service account**, in three parts
   that are easy to think are one step but aren't:
   a. Create the service account itself in Google Cloud Console (IAM & Admin
      -> Service Accounts; Play Console's Setup -> API access page links
      here) and download its JSON key.
   b. **Enable the Android Publisher API** on that same Google Cloud project
      (`console.developers.google.com/apis/api/androidpublisher.googleapis.com/overview?project=<id>`) -
      it's off by default, and the upload step fails clearly but only at
      upload time if it's missed. Allow a few minutes for it to propagate.
   c. **In Play Console itself**, go to Users and permissions, invite the
      service account's email (the JSON key's `client_email`) as a new
      user scoped to this app only, and grant **"Release apps to testing
      tracks"**. Creating the account in Google Cloud grants it no Play
      Console access by itself - skipping this produces a distinct
      "The caller does not have permission" upload failure, propagates
      quickly (no email-acceptance step like a human invite), but is easy
      to miss since nothing in Google Cloud's UI mentions it.
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

The optional `Promote Android testing release` workflow copies an existing
version from `internal` to a closed `alpha` or `beta` track. Promotion must
leave the source release active: the existing internal cohort and a closed
tester group can be configured independently, and removing the internal
release can otherwise leave those testers with no available update even
though the promotion workflow succeeded.

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
