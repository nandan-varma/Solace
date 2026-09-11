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
- [ ] `@Table` models (`CachedProduct`, `CachedGenericFood`, `UserProfile`, `AIProviderSettings`, `DiaryEntry`)
- [ ] `AppDatabase` + `SyncEngine` wiring
- [ ] `KeychainStore` (AI key + FDC key)
- [ ] `OpenFoodFactsClient`
- [ ] `USDAClient`
- [ ] `ScoringEngine` + unit tests
- [ ] `BarcodeScannerView` (VisionKit)
- [ ] Scan tab end-to-end + Product Detail screen
- **Done when:** scanning a real barcode on a physical device returns and displays correct Nutri-Score/NOVA/Green-Score data, and a generic-food search returns correct USDA macros. *(Automated: unit tests over fixture data + `xcodebuild test`; live camera scan is a manual check on the user's device.)*

## Phase 2 — Diary core
- [ ] Generic-food search screen
- [ ] `DiaryEntry` logging from product/genericFood sources
- [ ] Mifflin-St Jeor target calculator + unit tests
- [ ] Today view
- [ ] `HealthKitManager` writes
- [ ] History/Trends tab
- **Done when:** a logged entry appears correctly in both the app's Today view and the system Health app, and syncs to a second device/simulator via CloudKit within a reasonable delay. *(Automated: Simulator Health app write-through; cross-device CloudKit sync is a manual check.)*

## Phase 3 — On-device AI
- [ ] `SystemLanguageModel` availability gate + degraded UI
- [ ] `ScoreExplanation` flow on Product Detail
- **Done when:** explanations are factually consistent with the underlying numbers across at least 20 varied test products (no invented figures). *(Needs Apple Intelligence-eligible hardware — manual check.)*

## Phase 4 — Cloud AI + photo logging
- [ ] Settings screen (profile, targets, weights, allergens, AI config)
- [ ] `OpenAICompatibleClient`
- [ ] Photo capture → editable draft → save flow
- [ ] Invalid/deprecated model string → clear in-app error
- **Done when:** a photo of a known reference meal produces an estimate within the expected ~15-30% error range, and an invalid/deprecated model string produces a clear in-app error rather than a crash. *(Automated: mocked success/error JSON unit tests; real accuracy needs the user's own API key — manual check.)*
