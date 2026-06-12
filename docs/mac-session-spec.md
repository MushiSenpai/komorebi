# Mac Session Spec — Komorebi iOS & macOS release pathway

> **How to run:** on the Mac, `git clone https://github.com/MushiSenpai/komorebi`
> (or pull), `cd komorebi`, start Claude Code, and say:
> *"Execute docs/mac-session-spec.md"*.

## Context for the executing agent

You are on Mushi's macOS machine. Komorebi is a finished Flutter app
(Linux/Android verified; CI compiles iOS and macOS green on every push —
so the code is known-good and **any failure below is an environment or
signing issue, not an app bug**). Your job is to take both Apple targets
from "compiles in CI" to "runs on this Mac / ready for TestFlight".
The full human-readable runbook is `docs/RELEASING.md`; this spec is the
executable version.

Ground rules:
- Work phase by phase; verify each gate before the next. Commit nothing
  unless a phase explicitly says to. **Never commit or echo signing
  material** (certificates, profiles, passwords, key.properties).
- Mushi reads code fluently but does not hand-write it; explain decisions
  and trade-offs as you go.
- Anything needing his Apple ID, a purchase, or a security prompt: pause
  and hand it to him explicitly — those are his steps, listed per phase.

## Phase M0 — Toolchain (gate: `flutter doctor` green)

1. Check: `xcodebuild -version`, `flutter --version`, `pod --version`.
2. Missing pieces, in order: Xcode from the App Store (large; if not
   installed, ask Mushi to start it and continue when done), then
   `sudo xcodebuild -license accept`, `xcode-select --install`,
   Flutter via the official installer or `brew install --cask flutter`,
   CocoaPods (`brew install cocoapods` or `sudo gem install cocoapods`).
3. `flutter pub get` in the repo, then `flutter doctor` until the Xcode
   section is green. Run `flutter test` — all ~86 tests should pass on
   macOS too; report any that don't (environment signal, see P-25 class
   issues: set TMPDIR if /tmp is constrained — unlikely on macOS).

## Phase M1 — macOS app running locally (gate: app launches with data)

1. `flutter run -d macos` (debug). Verify: all seven tabs render, theme
   switch persists, create a task, plan a day-block, play one tower run
   (space rotates, enter drops).
2. Known entitlement: `macos/Runner/Release.entitlements` already has
   `com.apple.security.network.client` for the Arena. Debug entitlements
   include it by default. If Arena boards show "unreachable", check
   https://arena.theinvalid.me/api/health first.
3. `flutter build macos --release` and launch the bundle from
   `build/macos/Build/Products/Release/komorebi.app`. Gate: it opens and
   the Play tab works (sandbox release build exercises entitlements).

## Phase M2 — iOS on a device/simulator (gate: app runs)

1. `open -a Simulator`, then `flutter run -d iphone` (any iOS 17+ sim).
   Verify the same smoke list; touch controls in the game.
2. **Mushi's step:** for a physical iPhone, plug it in, trust the Mac,
   and (free tier is fine for local runs) open
   `ios/Runner.xcworkspace` in Xcode → Signing & Capabilities → Team →
   his personal team. Then `flutter run -d <device>`.

## Phase M3 — Apple Developer Program (all Mushi, agent waits)

- Enroll at https://developer.apple.com/programs/ ($99/yr) with his
  Apple ID. This unlocks TestFlight, App Store Connect, and notarization
  for BOTH platforms. Nothing in M4+ works without it.

## Phase M4 — Store identities (gate: archives upload cleanly)

1. In Xcode (both `ios/Runner.xcworkspace` and
   `macos/Runner.xcworkspace`): set Team to the new org/personal team;
   bundle id stays `dev.mushi.komorebi`. "Automatically manage signing"
   on. (Agent can edit project settings; the Apple-ID sign-in inside
   Xcode is Mushi's.)
2. App Store Connect (Mushi signs in, agent can guide): create the app
   record — name **Komorebi**, bundle `dev.mushi.komorebi`, platforms
   iOS + macOS under one record.
3. Build + upload:
   - iOS: `flutter build ipa --release` → upload
     `build/ios/ipa/komorebi.ipa` with the Transporter app (or
     `xcrun altool`).
   - macOS: `flutter build macos --release`, then Xcode → Product →
     Archive → Distribute → App Store Connect.
4. Gate: both builds show "Processing → Ready to Test" in App Store
   Connect; add Mushi as internal TestFlight tester for iOS.

## Phase M5 — Submission prep (agent drafts, Mushi approves)

- Screenshots: take from the running apps (light Meadow + dark Twilight;
  Today, Plan, Calendar, Notes, Focus, the game). Required sizes: 6.7"
  iPhone + 13" iPad for iOS; 1280×800+ for macOS.
- Listing copy: draft from README's voice ("calm, Ghibli-inspired,
  local-first productivity…"). Privacy questionnaire answers: **no data
  collected** except the optional, off-by-default Arena (user-chosen
  handle + game scores, not linked to identity, no tracking, no ads).
- Export compliance: uses only standard HTTPS — answer "exempt".
- Stop before pressing "Submit for Review" — that's Mushi's button.

## Report back

End the session with: toolchain versions installed, which gates passed,
links/IDs created (no secrets), screenshots taken, and a short list of
anything deferred — and append any new lessons to
`theinvalid-site/pipeline/queue.md` §B per the standing convention.
