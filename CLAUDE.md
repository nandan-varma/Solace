# CLAUDE.md

## Commands

- Build (Simulator): `xcodebuild build -project Solace.xcodeproj -scheme Solace -destination "id=<simulator-udid>"` (or `-destination "generic/platform=iOS Simulator"`)
- Unit tests only (fast): `xcodebuild test -project Solace.xcodeproj -scheme Solace -destination "id=<simulator-udid>" -only-testing:SolaceTests`
- UI tests (slow, boots a full app): `xcodebuild test -project Solace.xcodeproj -scheme Solace -destination "id=<simulator-udid>" -only-testing:SolaceUITests`
- Single test: append `/ClassName/testMethod` to the `-only-testing:` target, e.g. `-only-testing:SolaceTests/ScoringEngineTests/safeProductGetsAMatchScoreAndNoFlags`
- List/boot a simulator: `xcrun simctl list devices` / `xcrun simctl boot <udid>`
- No linter/formatter is configured — match surrounding style by hand.
- `web/` is an unrelated Astro marketing site (`solace.nandan.fyi`) with its own `CLAUDE.md`; commands above are for the iOS app only.

## Architecture

See `ARCHITECTURE.md` for the full data-flow and AI-tier writeup. Non-obvious points an agent needs before editing:

- **No backend, ever.** Two reference caches (`CachedProduct` from Open Food Facts, `CachedGenericFood` from USDA) are crowd-sourced/government data and are deliberately **never synced**. Everything else (`UserProfile`, `AIProviderSettings`, `DiaryEntry`) syncs via CloudKit under the user's own iCloud account. Don't add a server or any developer-owned datastore — it contradicts the whole design and the published privacy policy.
- **Credentials never touch SQLite.** The AI provider API key and the USDA FDC key live only in `KeychainStore`. `AIProviderSettings` stores the *config* (base URL, model string) but never the key itself.
- **HealthKit is write-only by contract, not just by convention.** `HealthKitManager.requestAuthorization` is called with `read: []`. If you ever add a read type, you must also add the matching `NSHealth*UsageDescription` in `Solace.xcodeproj/project.pbxproj` (both Debug and Release configs) or App Store uploads fail validation — this already bit us once for `NSHealthShareUsageDescription`, which Apple requires simply because the HealthKit capability is linked, regardless of whether read types are requested.
- **Two independent AI tiers**, not one feature behind a flag: on-device (Apple Foundation Models, default on, explains an already-computed score, never invents numbers) and cloud (BYOK, opt-in, only powers photo estimation, always produces an editable draft that is never auto-saved).
- **Scoring is a pure function.** `Scoring/ScoringEngine.swift` has no I/O and always evaluates allergen/diet safety first, unconditionally, before computing any composite score.
- `Solace/Dev/DevDataSeeder.swift` and `Solace/Features/Settings/DevSettingsSection.swift` are `#if DEBUG` — compiled out of Release entirely, not just hidden. Use "Seed Sample Data" there (or the `--reset-onboarding` launch argument) rather than hand-seeding when you need realistic data in Simulator.
- `TARGETED_DEVICE_FAMILY` is intentionally iPhone-only (`1`). Nothing in the UI has been tuned for iPad — don't re-enable iPad support without doing that work, since App Store screenshots become required for it again.

## Conventions

- Release signing is **manual** (`Apple Distribution` identity + the `Solace App Store` provisioning profile), Debug is Automatic. Don't flip Release back to Automatic signing.
- UI tests drive real accessibility identifiers/labels (see `SolaceUITests/SolaceUITests.swift`) — e.g. `app.buttons["Skip setup"]`, `app.buttons["onboarding.continue"]`. Keep label/identifier strings in sync with these tests when touching onboarding, Scan, or Settings.
- Full architecture spec and phase history are in `ARCHITECTURE.md`. There is no `ROADMAP.md` — all planned phases shipped; treat `ARCHITECTURE.md`'s "Known risks" section as the current open-items list instead.
