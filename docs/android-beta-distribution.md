# Android beta distribution and emulation

## Recommended TestFlight equivalent

Use Google Play **Internal testing** as the Android equivalent of TestFlight.
It installs through the Play Store, supports up to 100 invited testers, and
normally makes a newly uploaded Android App Bundle available within minutes.
The manual `Android Internal Testing` GitHub workflow builds a signed release
bundle and uploads it to that track.

Firebase App Distribution is a useful earlier-stage alternative when a Play
Console app is not ready. It can email testers and distribute a signed APK, but
installs do not use the normal Play Store update path. GitHub debug artifacts
remain developer downloads rather than a tester distribution channel.

## One-time Google Play setup

1. The permanent Android application ID is `app.tailendcharlie`, matching the
   `tailendcharlie.app` domain in reverse-DNS form. Confirm this is still
   correct before creating the Play Console app: Google Play package names
   cannot be changed after the first upload.
2. Create **Tail End Charlie** in Google Play Console and enrol it in Play App
   Signing.
3. Create a dedicated upload keystore. Back it up in an approved password or
   secrets vault before adding it to CI; do not commit it.
4. Create a least-privilege Google Cloud service account, enable the Google Play
   Android Developer API, and grant it release access for this app's internal
   track in Play Console.
5. Create the protected GitHub environment `android-internal` and add these
   environment secrets:

   - `ANDROID_UPLOAD_KEYSTORE_BASE64`
   - `ANDROID_UPLOAD_KEY_ALIAS`
   - `ANDROID_UPLOAD_KEY_PASSWORD`
   - `ANDROID_UPLOAD_STORE_PASSWORD`
   - `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

6. Add the initial tester email list under **Testing > Internal testing**, then
   share the Play opt-in URL.
7. Run **Android Internal Testing** from GitHub Actions. Its version code must be
   higher than every previous Play upload; the GitHub run number is the default.

Normal pushes and pull requests never publish a beta. The workflow is manual,
serialized, scoped to the protected environment, and pins every third-party
action to a reviewed commit.

## Android emulator

Android Studio includes the Android Emulator, the equivalent of Apple's iOS
Simulator. Each Android Virtual Device (AVD) has a chosen phone model, Android
API level, storage, and optional Play Store image. The emulator can simulate
location, rotation, network conditions, calls, sensors, tablets, Wear OS, TV,
and Android Automotive devices.

After installing Android Studio and Flutter:

1. Open **Tools > Device Manager** and create a current Pixel AVD with a Google
   Play system image.
2. Start the AVD and confirm it appears in `flutter devices`.
3. From `apps/mobile`, run `flutter run -d <device-id>`.
4. Exercise route import, location changes, offline transitions, permissions,
   and lifecycle recovery. Use real Android and iPhone hardware for Nearby
   Connections, background behaviour, power use, and cross-platform field
   evidence; simulators are not sufficient for those release gates.

Command-line equivalents are available after the SDK is installed:

```bash
emulator -list-avds
emulator -avd <avd-name>
flutter devices
flutter run -d <device-id>
```

## Sources

- [Google Play internal testing](https://support.google.com/googleplay/android-developer/answer/9845334)
- [Android Emulator](https://developer.android.com/studio/run/emulator)
- [Flutter Android release builds](https://docs.flutter.dev/deployment/android)
- [Firebase App Distribution](https://firebase.google.com/docs/app-distribution/android/distribute-cli)
