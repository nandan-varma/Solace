# Solace — Roadmap

Build phases from the architecture spec, each gated on a concrete acceptance check.

## Phase 0 — Project setup & design system
- [x] SQLiteData SPM dependency added and resolved
- [x] CloudKit + HealthKit entitlements, camera/health Info.plist usage strings
- [x] Simulator device created for build/test
- [x] Design system: Color/Typography/Spacing tokens + ScoreRing, NutriScoreBadge, NovaBadge, GreenScoreBadge, MacroPill, SafetyBanner, CardBackground
- [x] `ARCHITECTURE.md` / `ROADMAP.md`
- **Done when:** `xcodebuild build` succeeds for an iOS Simulator destination.

## Phase 1 — Foundation
- [x] `@Table` models (`CachedProduct`, `CachedGenericFood`, `UserProfile`, `AIProviderSettings`, `DiaryEntry`)
- [x] `AppDatabase` + `SyncEngine` wiring
- [x] `KeychainStore` (AI key + FDC key)
- [x] `OpenFoodFactsClient` (unit-tested against a captured real Nutella response)
- [x] `USDAClient` (unit-tested against a captured real banana search response)
- [x] `ScoringEngine` + unit tests
- [x] `BarcodeScannerView` (VisionKit)
- [x] Scan tab end-to-end + Product Detail screen (manual-entry fallback for Simulator, which has no camera)
- **Done when:** scanning a real barcode on a physical device returns and displays correct Nutri-Score/NOVA/Green-Score data, and a generic-food search returns correct USDA macros. *(Automated: 10/10 unit tests pass over real fixture data; app builds and launches in Simulator. Live camera scan on a physical device is still a manual check for the user.)*

## Phase 2 — Diary core
- [x] Generic-food search screen (USDA-first)
- [x] `DiaryEntry` logging from product/genericFood sources (shared `LogEntryControl`)
- [x] Mifflin-St Jeor target calculator + unit tests (verified against hand-calculated examples)
- [x] Today view (energy ring, macro cards, quick entry, meal-slot log)
- [x] `HealthKitManager` writes (opt-in, write-only, de-duped via `healthKitSampleUUID`)
- [x] History/Trends tab (Swift Charts, last 7 days)
- [x] Settings screen: body stats/targets, scoring weights, allergen/diet exclusions, HealthKit + on-device AI toggles (BYOK cloud AI fields deferred to Phase 4)
- **Done when:** a logged entry appears correctly in both the app's Today view and the system Health app, and syncs to a second device/simulator via CloudKit within a reasonable delay. *(Automated: 15/15 unit tests pass; app builds and runs in Simulator with live data flowing through Today/Trends. HealthKit write path and cross-device CloudKit sync still need manual confirmation on the user's devices.)*

## Phase 3 — On-device AI
- [x] `SystemLanguageModel` availability gate + degraded UI (`OnDeviceExplainer`, verified against the real iOS 26 SDK's `FoundationModels.swiftinterface`)
- [x] `ScoreExplanation` flow on Product Detail, gated on `UserProfile.onDeviceAIEnabled`
- **Done when:** explanations are factually consistent with the underlying numbers across at least 20 varied test products (no invented figures). *(App builds and the availability-gated UI is wired end-to-end; real generation output needs Apple Intelligence-eligible hardware — manual check for the user, since this dev environment can't run/verify the actual model output.)*

## Phase 4 — Cloud AI + photo logging
- [ ] Settings screen (profile, targets, weights, allergens, AI config)
- [ ] `OpenAICompatibleClient`
- [ ] Photo capture → editable draft → save flow
- [ ] Invalid/deprecated model string → clear in-app error
- **Done when:** a photo of a known reference meal produces an estimate within the expected ~15-30% error range, and an invalid/deprecated model string produces a clear in-app error rather than a crash. *(Automated: mocked success/error JSON unit tests; real accuracy needs the user's own API key — manual check.)*
