# Solace — Architecture

AI-native food scanner & diary tracker. iOS 26+, SwiftUI, free/open-source, no paid tier.

## Layers

```
Features/            SwiftUI screens (Today, Scan, Diary, History, Settings, PhotoLog)
   ↓ reads/writes
Models/               @Table structs (SQLiteData) — the single source of truth
   ↑ populated by
Networking/           OpenFoodFactsClient, USDAClient, OpenAICompatibleClient, KeychainStore
Scoring/               ScoringEngine — pure function over Models, no I/O
AI/                     OnDeviceExplainer (Foundation Models), CloudPhotoEstimator (BYOK)
HealthKit/              HealthKitManager — one-way write of DiaryEntry → Health
DesignSystem/           Color/Font/Spacing tokens + reusable components (badges, rings, cards)
```

## Data model

Two reference caches, **never synced** (crowd-sourced/government data, not user data):
- `CachedProduct` — Open Food Facts, keyed by barcode.
- `CachedGenericFood` — USDA FoodData Central, keyed by `fdcId`.

Everything else syncs via CloudKit (`SyncEngine`, on by default, no paywall):
- `UserProfile` — singleton row: body stats, activity level, allergen/diet exclusions, scoring weights, AI toggles.
- `AIProviderSettings` — singleton row: BYOK cloud AI config (base URL + model string; **the API key itself lives in Keychain only, never in this table**).
- `DiaryEntry` — one row per logged food, snapshotted at log time (never retroactively recomputed if the source cache updates).

Credentials (never synced, never in SQLite): the AI provider API key and the USDA FDC API key both live in `KeychainStore`, keyed separately. FDC defaults to the public `DEMO_KEY` if the user hasn't set their own.

## Data flow: logging a food

1. **Barcode scan** (VisionKit) → `OpenFoodFactsClient` (cache hit or network fetch) → `CachedProduct` → `ScoringEngine` → Product Detail screen → user taps Log → `DiaryEntry(sourceKind: "product")`.
2. **Generic search** → `USDAClient` → `CachedGenericFood` → same detail/log flow → `DiaryEntry(sourceKind: "genericFood")`.
3. **Photo** → `CloudPhotoEstimator` (BYOK, only if `AIProviderSettings.isEnabled`) → structured draft (editable, never auto-saved) → best-effort match against the two caches, else standalone → `DiaryEntry(sourceKind: "photoEstimate")`.

All three converge on the same `DiaryEntry` table, which drives Today's totals, History charts, and (opt-in) HealthKit writes.

## Scoring engine (`Scoring/ScoringEngine.swift`)

Pure, synchronous, unit-tested. Evaluation order:
1. **Safety first, unconditionally** — cross-reference allergens/diet flags against `UserProfile`. Any hit → `SafetyFlag`s returned, composite score suppressed regardless of how "healthy" the product otherwise looks.
2. Nutri-Score / NOVA / Green-Score passed through as their own badges — never reskinned or recolored beyond their certified palettes.
3. If safe, a weighted composite `matchScore` (0-100) from `UserProfile`'s editable weights, with the full per-factor `breakdown` always available (never hidden behind the top-line number).

## AI: two independent tiers

- **Tier 1 (on-device, default on)**: Apple Foundation Models, gated on `SystemLanguageModel.default.availability` (iOS 26 floor does not guarantee Apple Intelligence-eligible hardware) and `UserProfile.onDeviceAIEnabled`. Used only for explaining an already-computed score — never invents nutrition numbers.
- **Tier 2 (cloud, opt-in, BYOK)**: only active once `AIProviderSettings.isEnabled` and a Keychain key exist. User supplies base URL, model string, and key — no embedded developer key. Powers photo-based food estimation; every result is an editable draft, never auto-logged.

## Known risks (carried from spec, see ROADMAP.md for status)

- Nutri-Score algorithm version mixing (`CachedProduct.nutriscoreVersion` exists specifically to detect and surface this, not hide it).
- `DiaryEntry` can reference a cache row that doesn't exist on the syncing device — every read path needs a cache-miss → re-fetch fallback.
- Photo-estimate accuracy is a structural, published limitation (±15-30% single item, worse for composed dishes) — UI must show confidence, not just this doc.
- Keychain keys must never reach logs, crash reports, or analytics.

## External data sources

- Open Food Facts API v3 (`world.openfoodfacts.org`) — ODbL, custom `User-Agent: Solace/<version> (nandanvarma.me@gmail.com)` required, attribution shown in-app.
- USDA FoodData Central API (`api.nal.usda.gov`) — public domain, BYOK header, `DEMO_KEY` fallback.
