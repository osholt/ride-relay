# Next-agent handoff

Updated: 2026-07-19

## Start here

The production website is live at <https://tailendcharlie.app>. Cloudflare Pages
is connected directly to `osholt/tailendcharlie`, with `main` as the production
branch and `apps/website` as the output directory. The apex, `www`, and
`tailendcharlie.pages.dev` domains were verified over HTTPS.

`main` is currently at `34104e0` (`ci: use Cloudflare Pages Git deployment`).
Do not redo the Cloudflare/GitHub application setup.

## Active work

| Priority | Work | Current state | Next action |
|---|---|---|---|
| 1 | [Issue #5: navigation handoffs](https://github.com/osholt/tailendcharlie/issues/5) | [Draft PR #9](https://github.com/osholt/tailendcharlie/pull/9) is green. It adds a target capability registry with explicit transport, route fidelity, Android/iOS support, documented-link routing, and GPX fallback. | Review and merge the useful registry increment without closing #5. Physical-device/provider evidence remains. |
| 2 | [Issue #11: Android internal testing](https://github.com/osholt/tailendcharlie/issues/11) | [Draft PR #12](https://github.com/osholt/tailendcharlie/pull/12) is green. It adds optional release signing, a manual Google Play Internal Testing workflow, and Android beta/emulator documentation. | Resolve the permanent package ID and upload-key backup decisions before making the PR ready or attempting a Play upload. |
| 3 | [Issue #6: CarPlay and Android Auto](https://github.com/osholt/tailendcharlie/issues/6) | Roadmap only. No entitlement, car app service, template UI, or native simulator prototype exists. | Start with an Android Auto/Automotive prototype after the Android toolchain is installed; treat Apple navigation entitlement approval as an external gate. |
| 4 | [Issue #7: cross-app mini-map](https://github.com/osholt/tailendcharlie/issues/7) | Feasibility work only. The existing Flutter mini-map cannot remain visible over another iOS app. | Prototype a user-initiated, noninteractive Android PiP activity. For iOS, assess Live Activities or CarPlay rather than fake-video PiP. Write a platform decision record. |

[Draft PR #8](https://github.com/osholt/tailendcharlie/pull/8) is an older,
stale navigation-roadmap branch with a failed mobile check and no current-main
sync. Review its document for any unique material, then either update it or
close it as superseded; do not merge it blindly.

## Recommended execution order

1. Review PR #9 and keep its body as `Tracks #5`, not `Closes #5`. The registry
   increment is automated and green, but issue #5 explicitly requires installed
   app/device evidence that has not happened.
2. Ask the user to confirm the permanent Android application ID. The current
   value is the legacy `me.osholt.ride_relay`; `app.tailendcharlie` is the
   recommended public identifier because it matches `tailendcharlie.app` in
   reverse-DNS form. Google Play will make the choice permanent after the first
   upload. If changed, update the Android `applicationId` and PR #12 workflow
   `packageName`; do not casually rename the Nearby service or Flutter package.
3. Obtain explicit approval before installing Android Studio, the Android SDK,
   or Flutter on this Mac. They are not installed now. Create a current Pixel
   AVD with a Google Play image, run `flutter doctor`, launch the app, and record
   emulator smoke-test evidence.
4. Agree an encrypted, durable backup location before generating the Android
   upload keystore. Never leave the only copy in GitHub secrets or on a CI
   runner.
5. Create the Tail End Charlie app in Google Play Console, enrol in Play App
   Signing, create a least-privilege service account, create the protected
   `android-internal` GitHub environment, add the five secrets documented by PR
   #12, add testers, and run the first internal-track upload.
6. Verify install and update through the Play Store on a physical Android phone.
   The emulator is useful for UI/lifecycle work but does not satisfy Nearby,
   battery, background, or mixed-device field gates.
7. Use the installed Android tooling for the issue #6 and #7 native feasibility
   prototypes. Keep each issue in its own branch/PR.

## Android beta decisions

Google Play Internal Testing is the recommended TestFlight equivalent: it uses
the normal Play Store install/update path and supports a controlled tester list.
Firebase App Distribution is the fallback if a pre-Play APK channel is needed,
but it is not the preferred long-term update path.

PR #12 expects these protected-environment secrets and publishes only when
manually dispatched:

- `ANDROID_UPLOAD_KEYSTORE_BASE64`
- `ANDROID_UPLOAD_KEY_ALIAS`
- `ANDROID_UPLOAD_KEY_PASSWORD`
- `ANDROID_UPLOAD_STORE_PASSWORD`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

Do not run the upload workflow until the package ID, Play app, service account,
upload-key backup, and tester list are all confirmed.

## Verification evidence

As of this handoff, PR #9 and PR #12 both completed successfully with:

- Dart formatting and Flutter analysis;
- 95 Flutter tests;
- Android debug APK build;
- unsigned iOS debug build;
- server lint, tests, PostgreSQL migration smoke test, and container build; and
- Cloudflare Pages preview deployment.

The repository was clean after each push. PR #9 was synced with current `main`
because its older branch initially lacked `apps/website`; that sync fixed its
Cloudflare preview without changing the intended three-file feature diff.

## Remaining evidence boundaries

- Issue #5 still needs physical iOS/Android tests with installed navigation apps
  and representative Garmin/BMW workflows.
- Issue #6 needs official vehicle templates/simulators and Apple entitlement
  eligibility before any availability claim.
- Issue #7 must remain policy-compliant: no private APIs and no map disguised as
  video to obtain iOS PiP.
- The full P0 field-test gates in `PLAN.md` and `docs/field-test-plan.md` remain
  authoritative for Nearby radio behaviour, background recovery, battery use,
  marker accuracy, route alerts, and mixed-device operation.
