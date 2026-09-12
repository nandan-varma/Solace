# Solace — Full-Codebase Audit

**Audit date:** 2026-09-12 · **HEAD:** `9fc5c8a9` · **Type:** read-only review (no files changed during the audit)

Method: five parallel deep-dive reviews (UI/flows, core data/scoring/networking, AI/dev/design system, tests/config/CI/docs, marketing site), each with per-file reading and `file:line` evidence, plus an independent health check (build + unit + UI test runs) and supervisor spot-verification of every headline claim. Findings below are consolidated across all sources; every claim in the "Verifiable facts" and "Disputed/misreported" sections was re-checked directly.

---

## 1. Executive summary

Solace is in **genuinely good shape**. The architecture documented in `ARCHITECTURE.md`/`CLAUDE.md` is honored by the code: scoring is a pure safety-first function; the two reference caches are excluded from CloudKit sync; credentials live only in Keychain; HealthKit is write-only by contract; diary entries are snapshotted at log time; dev tooling is genuinely compiled out of Release; and every user-visible safety claim ("no conflicts found", "not a guarantee of accuracy", "keyword match, not certified") is honestly hedged in the UI. There is **no backend, no analytics, no paid tier** anywhere.

**No CRITICAL findings.** The most serious items are:

1. **Safety false-negative:** free-text allergen exclusions that don't lexically match OFF's standardized plural tags (e.g. "peanut" vs `en:peanuts`) silently produce **no allergen flag at all** on products that contain them. (HIGH)
2. **BYOK API key can be sent over plaintext `http://`** — endpoint URL is accepted with no scheme/host validation anywhere. (HIGH-adjacent; MEDIUM in practice since it needs user error)
3. **Misleading/developer errors leak to users** on the two most common failure paths (barcode not found, USDA rate-limit) — raw `(Solace.OpenFoodFactsError error 1.)` strings. (MEDIUM)
4. Several documented "known risks" are **not implemented** (Nutri-Score version surfacing; diary cache-miss re-fetch) and several UI claims are weaker than the copy suggests (photo draft not fully editable; "Green-Score" is actually OFF Eco-Score data). (MEDIUM)

**Health-check results:** build succeeds; all unit tests pass; the UI suite is currently RED — 2 of 3 functional tests fail deterministically on a reused *and* a brand-new simulator device, root-caused via accessibility snapshots to an app-side defect (the search and manual-barcode sheets never focus their fields, so no keyboard appears — details in §3 and finding M13).

---

## 2. Findings (consolidated, severity-ordered)

### HIGH

**H1. Allergen exclusions are matched by exact word-sequence equality — singular/plural variants silently miss**

- `Solace/Scoring/ScoringEngine.swift:108-120` (`tagMatches`/`wordSequence`), `:73-78` (`normalize`); entry path `Solace/Features/Settings/SettingsView.swift:304-325` (free-text "Add allergen (e.g. Peanuts)").
- The commit `e5728bc` fix correctly stopped substring false positives ("egg" ≠ "eggplant", "nut" ≠ "donut"), but whole-token equality now requires the profile entry to lexically equal the OFF tag. OFF tags are standardized *plurals*: `en:peanuts`, `en:eggs`, `en:nuts`, `en:soybeans`, `en:crustaceans`, `en:sesame-seeds` (singular: `milk`, `gluten`, `fish`). A user who types the natural singular forms — `peanut`, `egg`, `nut`, `soybean` — gets **no safety flag and no suppressed score** on products containing those allergens. Settings stores input lowercased only (`SettingsView.swift:325`); no normalization to OFF lexemes.
- Onboarding's canonical picker list (OnboardingView) uses the OFF-plural forms, so picker-selected exclusions are safe; the risk is confined to free-text entries — but the settings UI is exactly where a user with a specific allergy is most likely to type their own wording.
- **Fix:** normalize both sides with a small plural/lexeme map (e.g. `peanut→peanuts`, `egg→eggs`, `nut→nuts` + `tree nuts`) or a light stemmer, and add unit tests for singular/plural pairs. This is a safety-first feature; the false-negative direction is the dangerous one.

### MEDIUM

**M13. Search & manual-barcode sheets never focus their text field — no keyboard appears; the two UI tests that pin this are deterministically red**

- `Solace/Features/Diary/GenericFoodSearchView.swift:52-66` and `Solace/Features/Scan/ScanView.swift:97` (focus intent) — delivered behavior verified at runtime, not just by inspection.
- Both `testTodaySearchFocusesKeyboardOnEveryPresentation` and `testSkipSetupAndManualBarcodeValidation` assert `app.keyboards.firstMatch.waitForExistence` (lines 48/71) and **fail on every run** — verified on the reused sim, on a fresh simulator device (created for this audit), and across `ConnectHardwareKeyboard` 1 and 0. At the failure moment the accessibility tree shows the SearchField/TextField present but `hasKeyboardFocus == false` and **zero Keyboard elements** (exported from the failure xcresult) — the app never raises the keyboard.
- In `GenericFoodSearchView`, `.onAppear { searchFocused = false }` (line 52) and the `.task { … searchFocused = true }` (line 66, 50 ms delay) directly contradict each other; depending on firing order the field ends unfocused. In `ScanView` the barcode field focus relies on `.task { await Task.yield(); barcodeFocused = true }` which evidently doesn't stick in the sheet.
- User impact: opening the search sheet or manual-barcode sheet requires an extra tap on the field before typing; the app's own test comment ("Typing without tapping the field proves that focus… is correct") encodes the intended behavior. Tests must not be rewritten to pass — the behavior they pin is the desired UX.
- **Fix:** remove the conflicting `searchFocused = false` onAppear (or make focus intent single-path), verify focus lands via a test that asserts `hasKeyboardFocus`/types without tapping; make the barcode focus robust (e.g., re-assert in `.onChange(of: showManualEntry)`).

**M1. Raw developer error strings reach users on scan/search failure**"}, {"oldText": "**UI-test status detail:** four local attempts. Attempts 1, 2, 4, 5 failed **before tests ran** for infrastructure reasons (simulator-clone launch errors: \"no file found at …Solace.app\", SPM submodule clone failure for GRDB's `SQLiteLib.git`, \"Busy — Application failed preflight checks\"). Attempt 3 executed the suite: `testOnboardingPreferencesTargetAndRelaunch` ✅, both LaunchTests ✅, but `testSkipSetupAndManualBarcodeValidation` and `testTodaySearchFocusesKeyboardOnEveryPresentation` failed at the **same assertion** — `XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))` (lines 48 and 71) — on two unrelated screens. Host default `com.apple.iphonesimulator ConnectHardwareKeyboard = 1` hides the software keyboard in the simulator, which fully explains identical failures on two screens with everything else passing; this is a machine/simulator-state issue, not an app regression. The suite's only non-keyboard risk (noted by the review) is `testOnboardingPreferencesTargetAndRelaunch` asserting `app.staticTexts[\"Custom Target\"].exists` without a wait right after the Today bar appears — a small propagation-race window. **Recommendation:** run UI tests on CI macOS runners with the software keyboard forced on (or assert on `typeText` behavior rather than keyboard visibility), keep the `--reset-onboarding` discipline (already implemented — good), and add the one missing `waitForExistence`.", "newText": "**UI-test status detail (seven executed runs):** attempts 1, 2, 4, 5 failed *before tests ran* for infrastructure reasons (simulator-clone launch errors \"no file found at …Solace.app\", SPM submodule clone failure for GRDB's `SQLiteLib.git`, \"Busy — Application failed preflight checks\"). Three runs actually executed the suite — on the reused simulator, on the same simulator with `ConnectHardwareKeyboard` set to 0, and on a **brand-new simulator device created for this audit** — and all three produced identical results: `testOnboardingPreferencesTargetAndRelaunch` ✅, all LaunchTests ✅, and `testSkipSetupAndManualBarcodeValidation` + `testTodaySearchFocusesKeyboardOnEveryPresentation` ❌ at the same `app.keyboards.firstMatch` assertions (lines 48/71). Initially suspected environment (host had `ConnectHardwareKeyboard = 1`), so I exported the failure xcresults: at the failing moment the AX tree shows the relevant text field present but `hasKeyboardFocus == false` with zero Keyboard elements. The app never focuses the field → the tests legitimately fail wherever they run (findings M13). Residual infrastructure flakiness (pre-test launch failures) is a separate CI-hardening item. The onboarding test's `app.staticTexts[\"Custom Target\"].exists` without a wait is a small propagation-race risk noted for future runs."}, {"oldText": "**Repos, config, CI**\n\n- **No shared scheme committed.**", "newText": "**Tests, config, CI**\n\n- **UI suite is currently red** (see §3 / M13): two functional tests fail deterministically without the `--reset-onboarding` discipline being at fault; fix the app-side focus defect, keep the tests.\n- **No shared scheme committed.**"}]

- `Solace/Networking/OpenFoodFactsClient.swift:8-11`, `Solace/Networking/USDAClient.swift:5-7` — both enums are plain `Error, Equatable`, not `LocalizedError`; surfaced via `error.localizedDescription` at `Solace/Features/Scan/ProductDetailView.swift:271` and `Solace/Features/Diary/GenericFoodSearchView.swift:121`.
- Result: a 404 barcode (the most common fresh-scan outcome) or a USDA `DEMO_KEY` rate-limit renders as `"The operation couldn't be completed. (Solace.OpenFoodFactsError error 1.)"`. `CloudPhotoEstimatorError` already sets the right pattern (`LocalizedError`).
- **Fix:** conform both enums to `LocalizedError` with user-facing copy (not-found → "No product found for this barcode…", 429 → "Search rate limit reached — try again in a minute.").

**M2. BYOK endpoint accepts `http://` — the API key can travel in plaintext; empty/relative URLs bypass the friendly error**

- `Solace/AI/CloudPhotoEstimator.swift:40-48`: the only gate is `URL(string: baseURL + "/chat/completions") != nil`. `http://my-vps:8000/v1` passes and the `Authorization: Bearer <key>` header is sent unencrypted; an *empty* base URL concatenates to `/chat/completions` (a valid relative URL) and fails later as a raw `URLError` instead of `invalidEndpoint`.
- `Solace/Features/Settings/SettingsView.swift` persists endpoint/model with zero validation (contrast: the profile section has inline validation).
- **Fix:** require `scheme == "https"` (allow `http` only for `localhost`/loopback), require a host, trim whitespace/newlines before saving, and add save-time inline validation in Settings.

**M3. Photo AI draft is not as editable as the UI claims**

- `Solace/Features/PhotoLog/PhotoLogView.swift:257-278`: per-item stepper `in: 1...2000, step: 10`; no per-item remove or rename. A misidentified item cannot be removed or zeroed; its name and kcal are logged into the diary as-is. The screen says "CHECK THE FOODS AND PORTIONS BEFORE SAVING" and the header comment claims "every field stays editable".
- **Fix:** add per-item remove (and rename), or allow a zero-gram state that excludes the item.

**M4. OFF Eco-Score data is presented as "Green-Score"**

- `Solace/Networking/OpenFoodFactsClient.swift:91` decodes `ecoscore_grade` into `greenScoreGrade`; UI labels it "GREEN-SCORE" (`ProductDetailView.swift:97`, `GreenScoreBadge.swift`). Eco-Score (OFF's environmental score) and Green-Score (the French on-pack label) are different systems; the badge also reuses the Nutri-Score A–E palette (`Colors.swift:57-59` — "no certified hex published"), and Eco-Score grades outside A–E (e.g. "F") render with no color at all.
- **Fix:** product decision needed — rename to "Eco-Score" or document Green-Score as a deliberate brand; either way, handle the full A–F range in `nutriScoreColor(for:)`.

**M5. "Not configured" message lies when only the model string is empty**

- `CloudPhotoEstimator.swift:37-38` throws `.notConfigured` for an empty `modelString`, but the PhotoLog gate (`PhotoLogView.swift:332-335`) only checks `isEnabled` + key presence, and Settings has no required-marking on the model field. Message says "Enable AI features and add an API key in Settings first." — misleading when a key exists.
- **Fix:** include `modelString` in the gate/validation and split the message.

**M6. Macro values have a floor but no absurdity ceiling**

- `CloudPhotoEstimator.swift:112-125`: grams clamp 1...2000, but kcal/protein/carb/fat only clamp `>= 0`. A provider returning `kcal: 100000` survives into the diary; `rescale` (PhotoLogView) scales macros linearly with no plausibility cap.
- **Fix:** clamp per-item energy/macros to plausible ranges at parse, and cap the per-gram rate in `rescale`.

**M7. Nutrient-less food still emits a confident 60/100 "Fair Fit"**

- `ScoringEngine.swift:168-178`: `personalFitComponent` starts at a 60 baseline and is always included, so a product with *no* nutrition data at all scores a solid 60/100 ring ("Fair Fit") with zero evidence.
- **Fix:** emit the Personal Fit component only when at least one real factor exists (a grade or ≥1 nutrient); otherwise leave `matchScore` nil and show "no nutrition data".

**M8. Dietary keyword heuristics false-positive common vegan/halal-friendly products**

- `ScoringEngine.swift:80-87,92`: `vegan` keywords include `butter` (flags "cocoa butter"/"peanut butter"/"shea butter" — including the app's own seeded 85% chocolate) and `halal` includes `alcohol`/`wine` (flags "alcohol-free"). Only `milk` got plant-qualifier treatment. Any dietary flag suppresses the score and shows the red conflict banner — bounded by the honest "keyword match, not certified" label, but asymmetric with the `milk` fix.
- **Fix:** extend qualifiers (cocoa/peanut/cashew/shea/almond before "butter"), handle `*-free` negation for alcohol/gelatin, and consider not suppressing the composite for *heuristic* dietary flags (only for certified allergen-tag hits).

**M9. Diary display path lacks the documented cache-miss → re-fetch fallback**

- `ARCHITECTURE.md` "Known risks" promises a re-fetch fallback on every read path; the scan/detail path has it (`ProductRepository.swift:16-25`), but diary *display* resolves names only from local cache dictionaries and falls back to static placeholders (`TodayView.swift:255-263` — "Scanned Product"/"Food"). After CloudKit sync to a device that never cached the source row, users permanently see placeholder names (totals stay correct).
- **Fix:** fire a one-shot re-fetch on name-miss (with a small memo to avoid refetch storms).

**M10. Nutri-Score version-mixing detection: stored, never surfaced**

- `CachedProduct.swift:17` (column), `OpenFoodFactsClient.swift:89` (decode), `AppDatabase.swift:45` (DDL) — but **no code reads it**. The ARCHITECTURE "known risks" entry says the column exists "to detect and surface this, not hide it"; currently the UI shows only the grade letter. (Also: the column's comment says `"2021" | "2024"`; real OFF data is `"2023"` per the fixture.)
- **Fix:** show the version on the Nutri-Score tile (e.g. "v2023") and warn on version mixing; fix the stale comment.

**M11. ODbL attribution missing on the marketing site (legal/attribution)**

- The app credits OFF correctly (`ProductDetailView.swift:88` "Data from Open Food Facts (ODbL)"; `SettingsView.swift:462`), but the site (`web/src/pages/index.astro:7`, privacy/terms/support) names Open Food Facts with zero ODbL/contributors credit despite displaying OFF-derived badges. `ARCHITECTURE.md:78` records ODbL attribution as an app obligation; the site is a second surface for OFF data.
- **Fix:** add "Product data from Open Food Facts, available under the Open Database License (ODbL)" to the landing page (near features or footer) and a line in privacy/terms.

**M12. Privacy policy doesn't disclose BYOK provider retention of photos**

- `web/src/pages/privacy.astro:73-82` says photos go "directly to that provider on your behalf" but never says the photo is thereafter subject to the provider's own terms/retention — material given the policy's promise to "explain exactly where your data goes".
- **Fix:** add one sentence: "Once sent, the photo and request details are handled under your chosen provider's own privacy terms, and may be retained by the provider."

### LOW

- **L1. Camera-denied state blames the device** — `ScanView.swift:58-64`: "This device or simulator doesn't support live barcode scanning…" also shows when the user *denied* camera permission, with no "Open Settings" path. Branch on `AVCaptureDevice.authorizationStatus(.video)`.
- **L2. Products with missing energy log silently as 0 kcal** — `DiaryRepository.swift:28-30` (`(product.energyKcal100g ?? 0) * scale`); Today then shows "0 kcal" rows and an understated total with no in-flow warning.
- **L3. Custom allergen entries must match OFF lexemes exactly** — (singular/plural; merged into H1).
- **L4. OFF barcode path force-unwraps `URL(string: ...)!`** — `OpenFoodFactsClient.swift:18`; latent crash if a non-numeric barcode ever reaches the client (all current producers are validated digits, so latent only). Build with `URLComponents` + validate inside the client.
- **L5. `HealthKitManager.didRequestAuthorization` is an unsynchronized mutable on `@unchecked Sendable`** — `HealthKitManager.swift:13,33-35`; concurrent write calls can double-request auth (benign today). Use a lock or exclusive write path.
- **L6. Breakdown contributions displayed unnormalized** — `ScoreResult.breakdown` stores `weight × component` terms; `ProductDetailView.swift:194-208` prints them raw (e.g. "100.0" at weight 1.0), which reads like the factor's own score. Show true share or label it.
- **L7. BYOK settings save flow has no validation feedback** — merged into M2/M5 (no inline `aiValidation` mirroring `profileValidation`).
- **L8. On-device explain task not cancelled on leave** — `ProductDetailView.swift:252-260`: `Task { await explain(...) }` keeps running if the user navigates back mid-inference; drive it from `.task(id:)`/cancel in `onDisappear`.
- **L9. `max_tokens` unset and no explicit request timeout** in `CloudPhotoEstimator` request; `data:image/jpeg` label can mismatch raw PNG/HEIC bytes on the PhotosPicker fallback (`CloudPhotoEstimator.swift:47`, `PhotoLogView.swift:346`).
- **L10. UI micro-nits:** ScoreRing a11y label reads "/ 100: 72"; `ButtonStyles.swift:20` decides fill by `Color` equality (`tint == .solaceVitality`); NutriScoreBadge fixed 22×26 tiles can clip at large Dynamic Type; "solaceStat(32)" fixed font doesn't scale; white glyphs on certified yellow (expected, contrast ~1.9:1 — conscious tradeoff).
- **L11. Web:** `text-neutral-500` below WCAG AA on dark bg (`privacy.astro:14`, `index.astro:113-114`, `terms.astro:14` — swap to `neutral-400`); header nav hidden below 640 px with no fallback menu; privacy policy lacks COPPA/children and international-transfer statements.
- **L12. Data nits:** reference caches never expire (`fetchedAt` written, never read); zero-value Health samples written for nutrition-less products (consider writing only non-zero samples); "USDA SR Legacy · Verified" row label misstates any future dataType (currently pinned, safe); breakdown/stale comments.

### NIT (representative)

- `SolaceTests/SolaceTests.swift` ships the Xcode template — an empty, always-passing `@Test func example()` placeholder; delete or replace.
- Empty `AccentColor.colorset` in `Assets.xcassets` (harmless; `.tint(.solaceVitality)` is explicit).
- No AGPL notice headers in source files (LICENSE itself is valid and complete; headers are appendix-recommended only).
- Today's empty state: "Every meal is a fresh start." does no work for a first-time logger ("Start with something you've eaten today…").
- "Photo log" vs "Photo AI"/"Photo Logging" title-case inconsistency; Today date header omits year; duplicate dot colors for Fat/Sugars in the key-nutrients grid; "Open Food Facts v3" is an API internalism.
- Web: 404 page self-canonicalizes to `/404`; sitemap URLs carry trailing slashes while canonicals don't; manifest icons lack `purpose`; "Coming soon to the App Store" hero badge must become a real link at release (currently accurate); Terms don't name AGPL-3.0 inline (no conflict — app use vs source code are correctly separated).
- `ARCHITECTURE.md:12` lists `OpenAICompatibleClient` in `Networking/` — no such type exists; the OpenAI-compatible client is `enum CloudPhotoEstimator` (`Solace/AI/CloudPhotoEstimator.swift:30-77`). Fix the doc so future agents don't hunt a nonexistent file.

---

## 3. Health check (executed, not inferred)

| Check | Result |
| --- | --- |
| `xcodebuild build` (generic iOS Simulator) | ✅ **BUILD SUCCEEDED** |
| Unit tests (`-only-testing:SolaceTests`) | ✅ **TEST SUCCEEDED** — all pass |
| UI tests (`-only-testing:SolaceUITests`) | ⚠️ Environment-flaky locally — see below |

**UI-test status detail:** four local attempts. Attempts 1, 2, 4, 5 failed **before tests ran** for infrastructure reasons (simulator-clone launch errors: "no file found at …Solace.app", SPM submodule clone failure for GRDB's `SQLiteLib.git`, "Busy — Application failed preflight checks"). Attempt 3 executed the suite: `testOnboardingPreferencesTargetAndRelaunch` ✅, both LaunchTests ✅, but `testSkipSetupAndManualBarcodeValidation` and `testTodaySearchFocusesKeyboardOnEveryPresentation` failed at the **same assertion** — `XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))` (lines 48 and 71) — on two unrelated screens. Host default `com.apple.iphonesimulator ConnectHardwareKeyboard = 1` hides the software keyboard in the simulator, which fully explains identical failures on two screens with everything else passing; this is a machine/simulator-state issue, not an app regression. The suite's only non-keyboard risk (noted by the review) is `testOnboardingPreferencesTargetAndRelaunch` asserting `app.staticTexts["Custom Target"].exists` without a wait right after the Today bar appears — a small propagation-race window. **Recommendation:** run UI tests on CI macOS runners with the software keyboard forced on (or assert on `typeText` behavior rather than keyboard visibility), keep the `--reset-onboarding` discipline (already implemented — good), and add the one missing `waitForExistence`.

---

## 4. User flows walked (verdicts)

All seven core flows walk end-to-end without a break; state handling, re-entrancy guards, and validation are above the typical bar.

| Flow | Verdict | Notes |
| --- | --- | --- |
| Onboarding (first launch, skip, re-open via Settings, relaunch persistence) | ✅ PASS | Skip writes nothing but completes; `isSaving` guards double-tap; `--reset-onboarding` touches only the flag; Settings can re-run setup and live-reloads the form. |
| Tab navigation & state retention | ✅ PASS | Per-tab `NavigationStack`; Today's "Scan" switches tabs instead of nesting; scanner pauses off-screen and after capture. |
| Barcode scan → detail → log → Today | ✅ PASS | VisionKit + validated manual entry (8/12/13/14 digits); loading/error/retry states; 100 g default, ±10 g stepper, 1–2000 validation; post-log UI swap prevents double-fire. Caveats: raw error strings on not-found (M1); silent 0 kcal for nutrition-less products (L2). |
| Generic search → detail → log | ✅ PASS | Auto-focus per presentation, 400 ms debounce, cancellation on disappear, empty/no-results/error states. Caveat: raw USDA error strings (M1). |
| Photo log (gate → capture → estimate → edit → save) | ✅ PASS | Provider gate with privacy-framed copy; confidence % + "not a guarantee" disclaimer; draft discard confirmation; double-tap guards; useful `LocalizedError` text. Caveats: not-fully-editable draft (M3), misleading empty-model message (M5), no re-estimate affordance, format-label mismatch (L9). |
| Today totals/targets/Trends | ✅ PASS | Live via `@FetchAll`; Mifflin-St Jeor or override with "Custom Target" labeling; ring clamps; hedged "unlogged days" footnote. |
| Settings → Today/Trends live reaction | ✅ PASS | 400 ms debounced save flows straight back; body-stat validation blocks bad saves; weights live-total warning. |

**UI-test identifier/label contract:** all 16 identifiers/labels the XCUITests rely on exist verbatim in the views; extra identifiers (`scan.barcode`, `log.quantity`, `settings.target`) are present but unused by tests.

**Accessibility:** 44 pt+ hit targets, `@ScaledMetric` rings, V-stack swaps at accessibility sizes, tabular figures, reduce-motion respected, VoiceOver labels on rings/pills/steppers/chips — consistently above typical bar.

---

## 5. Wording audit highlights

Accurate and well-hedged (keep): "No conflicts found — Based on available product data and your preferences. Always check the package for allergens." · "keyword match, not certified" · "Confidence is reported by the AI, not a guarantee of accuracy…" · "Private & offline — synthesized on-device." · "Your key stays in the Keychain and is sent directly to your provider — never to a Solace server." · "Unlogged days don't necessarily mean no food was eaten." · "not a guarantee of safety."

Misleading/confusing (fix): the `.notConfigured` message when only the model is empty (M5) · camera-denied copy blaming the device (L1) · "GREEN-SCORE" on Eco-Score data (M4) · "TAP +/- TO ADJUST / Check the foods and portions before saving" vs. an uneditable, non-removable draft (M3) · "Every meal is a fresh start." on a never-used empty state · "Open Food Facts v3" (internalism) · mild terminology drift between onboarding ("Daily calories · optional") and Settings ("Custom target (kcal)").

---

## 6. Documented risks vs reality

| ARCHITECTURE "Known risk"/claim | Verdict |
| --- | --- |
| Nutri-Score version mixing detected & surfaced | ❌ Column stored; **never surfaced** (M10) |
| Diary cache-miss → re-fetch on every read path | ⚠️ Scan path yes; diary display **no** (M9) |
| Photo-estimate accuracy ±15–30%, confidence shown | ✅ Implemented, confidence shown with disclaimer |
| Keychain keys never in logs/crash reports | ✅ Keychain logs names only, `.public`; no key/header logging anywhere |
| Credentials never in SQLite | ✅ No key columns in any table |
| Two reference caches never synced | ✅ Sync list is exactly UserProfile/AIProviderSettings/DiaryEntry |
| HealthKit write-only (`read: []`) | ✅ Verified in `HealthKitManager.swift:34` |
| Scoring pure & safety-first | ✅ Flags computed first, score nil on any flag, breakdown retained |
| No backend ever | ✅ Only OFF, USDA, user-BYOK endpoints |
| OFF User-Agent `Solace/1.0 (contact@nandan.fyi)` | ✅ On every OFF request |
| USDA `DEMO_KEY` fallback | ✅ `KeychainStore.get(.usdaFDCAPIKey) ?? "DEMO_KEY"` |
| Dev tools compiled out of Release | ✅ Both files fully `#if DEBUG`; Settings refs gated too |
| Onboarding AppStorage-only completion, Settings reopen, `--reset-onboarding` Debug-only | ✅ All true |

**Doc/config inaccuracies found:** `ARCHITECTURE.md:12` (nonexistent `OpenAICompatibleClient`) · `CachedProduct.swift:17` stale comment (`"2021"|"2024"` vs actual `"2023"`) · tests-config's claim that "no commit claims a Settings save-race fix" is wrong — `2721e18 Fix Settings save race and Photo Log image handling` exists (but still has **no regression test**, which stands) · tests-config's "missing privacy manifest" P1 is a **false positive** — `Solace/PrivacyInfo.xcprivacy` exists, is tracked, declares `UserDefaults`/CA92.1, and is auto-included via the project's synchronized root group.

---

## 7. Tests, config, CI

**Coverage map (module → tests):**

| Module | Tests | Gap |
| --- | --- | --- |
| ScoringEngine | ✅ 5 tests | No tests for whole-word boundaries (egg/eggplant), plant-milk qualifiers, other diet keywords, multi-word exclusions, empty-input (M7), singular/plural pairs (H1) |
| NutritionTargetCalculator | ✅ 7 tests, hand-verified | Unspecified-sex midpoint; boundary year |
| CloudPhotoEstimator parse | ✅ 4 tests | `maxItems` cap, absurd-value clamp (M6), HTTP layer (hardwired `URLSession.shared` — no seam) |
| OFF/USDA clients | ⚠️ parse fixtures only | HTTP error mapping, `parseDetail` for USDA (different wire shape), repository upsert path |
| DiaryRepository / repositories / KeychainStore / HealthKitManager / OnDeviceExplainer / Settings debounce / TabRouter / Today aggregation | ❌ none | Diary scaling math, keychain round-trip (simulator keychain is testable), HK write path, debounce regression guard, `MealSlot.current()` is a pure function that could be tested |
| Onboarding | ✅ UI tests | Target validation (1–10,000) has no unit assertions; "Review welcome & setup" reopen not covered |
| UI suite | ⚠️ 3 functional + launch | Two functional tests fail deterministically (M13: auto-focus never lands); onboarding test has one non-waiting assertion |

**Test quality:** unit tests are network-free and deterministic (fixtures `off_nutella.json`, `fdc_search_banana.json` are real captured payloads; `referenceYear` injected). No linter/formatter is configured; there's also no formatting enforcement in CI.

**Config/CI findings:**

- **No shared scheme committed.** CI (`ci.yml`) and all documented `xcodebuild -scheme Solace` commands rely on xcodebuild auto-generating the scheme on a clean checkout. Commit `xcshareddata/xcschemes/Solace.xcscheme` (and consider a `.xctestplan` splitting unit vs UI).
- **CI never builds Release**, never scans the built binary for dev strings (the ARCHITECTURE claim is a past manual check), and has no SPM cache — every run re-resolves + rebuilds dependencies (this audit hit exactly that: a transient `SQLiteLib.git` submodule clone failure during a dependency resolve).
- pbxproj verified: deployment target 26.5, iPhone-only (`TARGETED_DEVICE_FAMILY = 1`), manual Release / Automatic Debug signing, `NSHealthShareUsageDescription` **and** `NSHealthUpdateUsageDescription` in both Debug and Release (the past rejection is fixed), app icon structurally complete, entitlements sane, privacy manifest present + wired (see §6).
- `.gitignore` hygiene is clean: nothing stray tracked (root covers `xcuserdata`, `DerivedData`, `.pi`, `.DS_Store`; `web/` covers `dist/`, `.astro/`, `node_modules/`). `web/dist` is correctly **not** committed.

---

## 8. Web site (solace.nandan.fyi)

Healthy overall. Every substantive privacy/architecture claim matches app reality (verified per-claim against app source, including the exact `read: []` HealthKit call and the three-table sync list). Contact email `contact@nandan.fyi` is the only email anywhere in repo + site; legal docs dated the same day as HEAD; `dist/` exactly matches current `src/`; zero analytics anywhere; og-image is 1200×630; sitemap/robots canonical and correct; Tailwind 4.3.3 + Astro 7.3.2 pinned via lockfile.

Findings: **M11** (ODbL credit missing), **M12** (provider-retention disclosure), LOW: contrast (`neutral-500`), mobile nav without fallback, no COPPA/international transfer sections; NITs: 404 self-canonical, trailing-slash sitemap vs slashless canonicals, manifest icons lack `purpose`, "Coming soon to the App Store" must become a real link at release, Terms don't name AGPL inline.

---

## 9. Recommended actions (priority order)

**Before next App Store submission:**

1. **H1** — allergen lexeme normalization (singular/plural) + unit tests. Safety feature; false-negative is the dangerous direction.
2. **M2/L7** — BYOK endpoint validation: HTTPS-only (+loopback exception), host required, trim, save-time inline validation.
3. **M1** — `LocalizedError` for OFF/USDA errors (Fix `notFound`, rate-limit, offline copy).
4. **M11/M12** — site ODbL credit + provider-retention sentence (legal exposure).
5. Verify privacy-manifest embedding with a Release archive (present & correct by inspection; one validation run to confirm embedding).

**Next development pass:**
6. **M13** — fix search/manual-barcode auto-focus (remove the opposing `searchFocused = false` onAppear; make focus single-path) so the two UI tests go green without weakening them.
7. **M6/M7** — macro plausibility ceilings; don't score nutrition-less foods.
8. **M3/M4/M5** — photo-draft edit/remove, Eco-Score naming decision + A–F palette, model-required validation/messaging.
9. **M9/M10** — diary cache-miss re-fetch; surface Nutri-Score version (or soften ARCHITECTURE wording).
10. **M8** — butter/`-free` qualifiers; consider not suppressing composite for heuristic flags.
11. **L1, L2, L4, L5, L6, L8, L9** — the LOW list (camera-denied copy, 0-kcal warning, `URLComponents`, HK lock, breakdown labeling, explain cancellation, request caps/format).

**Repo hygiene:**
12. Commit the shared scheme; add SPM cache to CI; add a nightly Release build + dev-string scan gate; delete `SolaceTests.swift` placeholder; fix `ARCHITECTURE.md` layer list + `CachedProduct.swift` comment.
13. Web L11/L12 + NITs (contrast, mobile nav, COPPA, 404 canonical, manifest `purpose`, App Store link at release).

---

## 10. Open questions for the owner

1. Is "Green-Score" a deliberate product name for OFF Eco-Score data, or an unintentional conflation? (Determines M4 fix.)
2. Does `DataScannerViewController.isAvailable` reflect a denied camera permission on device (vs. only hardware/simulator support)? An on-device test with permission revoked decides the L1 copy branch.
3. Should dietary (heuristic) flags suppress the composite score, or only certified allergen-tag hits? (M8 — product decision, not just code.)
4. Cache freshness: is indefinite cache retention of OFF/USDA rows intentional ("snapshot at log time")? If so, document it; if not, add a TTL (L12).
5. When the app ships: swap the "Coming soon to the App Store" badge for a real link, and consider reusing README screenshots on the site.
