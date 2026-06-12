# Releasing Komorebi

The pathway from this repo to the three app stores. CI already verifies
every push compiles for **Android (APK artifact), iOS (unsigned), and
macOS** — the steps below are the signing/store work that platforms require
a human (and, for Apple, a Mac) to do.

Versioning: bump `version:` in `pubspec.yaml` (e.g. `1.2.0+3` —
name `1.2.0`, build number `3`). Every store upload needs a higher build
number than the last.

---

## Android → Google Play

One-time setup:

1. Create the upload keystore (keep it forever; losing it means a new app
   listing):

   ```bash
   keytool -genkey -v -keystore ~/secure/komorebi-upload.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. `cp android/key.properties.example android/key.properties` and fill it
   in (`key.properties` is gitignored; the Gradle config picks it up and
   signs release builds automatically — without it, builds fall back to
   debug signing so development keeps working).

3. [Play Console](https://play.google.com/console): one-time $25 fee,
   create app **Komorebi** (`dev.mushi.komorebi`).

Each release:

```bash
flutter build appbundle --release    # build/app/outputs/bundle/release/app-release.aab
```

Upload the `.aab` to an **Internal testing** track first, then promote.
Data-safety form: no data collected or shared, except the optional Arena
opt-in (user-chosen handle + game scores, not linked to identity). No ads,
no tracking.

Sideloading (no store): `flutter build apk --release` and share the APK —
CI also attaches one to every main-branch run (artifact `komorebi-apk`).

---

## iOS → App Store (requires your Mac)

One-time setup on the Mac:

1. Install Xcode from the App Store + `xcode-select --install`; install
   Flutter and run `flutter doctor` until green; `sudo gem install cocoapods`
   if doctor asks.
2. Join the [Apple Developer Program](https://developer.apple.com/programs/)
   ($99/yr — covers iOS and macOS).
3. `git clone` this repo, `flutter pub get`, then
   `open ios/Runner.xcworkspace` in Xcode →
   *Signing & Capabilities*: select your Team; bundle id is
   `dev.mushi.komorebi`. Xcode manages certificates/profiles automatically.
4. In [App Store Connect](https://appstoreconnect.apple.com): create the
   app (same bundle id).

Each release, on the Mac:

```bash
flutter build ipa --release          # build/ios/ipa/komorebi.ipa
```

Upload with Xcode's *Transporter* app (or
`xcrun altool --upload-app`). Distribute via **TestFlight** first (instant
for internal testers), then submit for review. App-privacy answers mirror
Android's: no collection except the optional Arena handle+scores.

Smoke checklist before submitting: dark/light theme, notifications prompt,
Arena join + score sync, game touch controls, backup export.

## macOS → Mac App Store or notarized direct download

Same Mac, same membership.

- The sandbox entitlements already include `network.client` (Arena) —
  see `macos/Runner/Release.entitlements`.
- Mac App Store: `flutter build macos --release`, then archive in Xcode
  (*Product → Archive* on `macos/Runner.xcworkspace`) → *Distribute App →
  App Store Connect*. Same App Store Connect listing family as iOS.
- Direct download instead: *Distribute App → Developer ID*, then notarize
  (`xcrun notarytool submit ... --wait`) and staple; ship the .dmg from
  theinvalid.me.

---

## What CI guarantees vs. what it can't

| | CI (every push) | Needs a human/Mac |
|---|---|---|
| Analyze + 86 tests | ✅ ubuntu | |
| Android release build + APK artifact | ✅ ubuntu | Play signing & upload |
| iOS compiles | ✅ macos runner (`--no-codesign`) | Signing, TestFlight, review |
| macOS compiles | ✅ macos runner | Archive, notarize/store |

If the `apple` CI job is green, the Mac-side work is mechanical: open,
sign, upload.
