# Phase 7b manual tests: localization and App Store preparation

Six languages: English, 日本語, Русский, 简体中文, 繁體中文 (zh-Hant), 繁體中文 香港 (zh-HK). Copy source of truth is zh-Hant;
the String Catalog is `BoomOrBonus/Localizable.xcstrings` (keys are the zh-Hant text; legacy `DailyRecordsView` keys kept).

## A. Automated

| What | Command | Expect |
|---|---|---|
| Unit tests (run in zh-Hant: the scheme's Test action sets App Language zh-Hant / region TW) | `xcodebuild test -workspace BoomOrBonus.xcworkspace -scheme BoomOrBonus -destination 'id=F33D7A61-6A3D-4B1B-ACBE-027AB85592DE' -parallel-testing-enabled NO -only-testing:BoomOrBonusTests` | all pass |
| UI tests (all launch with `-AppleLanguages (zh-Hant) -AppleLocale zh_TW` via `LocaleArgs.zhHant`) | `... -only-testing:BoomOrBonusUITests/GameFlowUITests` (and `AdsUITests`, needs network) | all pass |
| Locale sweep | `TEST_RUNNER_SHOTS_DIR=<dir> xcodebuild test ... -only-testing:BoomOrBonusUITests/LocalizationUITests` | 6 tests pass; PNGs in `<dir>/<device>/<locale>/NN-name.png` |
| Store screenshots (iPhone 17 Pro Max simulator only) | see header of `StoreScreenshotsUITests.swift` | `docs/redesign/store/screenshots/<locale>/1..5` |
| Store text limits | `python3 docs/redesign/store/check-lengths.py` | OK |

What the sweep audit proves (and what it cannot): SwiftUI gives the full text as the accessibility label even when it is drawn
truncated, so truncation is not readable from labels or frames. The audit checks, on every screen of every language:
no CJK in en / ru (missing translation), no Traditional-only characters in zh-Hans / ja, no label ending in an ellipsis, nothing
drawn outside the screen horizontally, no two buttons overlapping. **Truncation itself is judged by eye on the screenshots** (section B).

## B. Visual check of the sweep (do on iPhone SE (3rd generation) and a Pro)

Open the PNGs of en, ru and ja first (the longest). For each screen look for: "..." at the end of a text, a word cut in the middle,
text running past a button or capsule, two texts overlapping, a button label cut off.

| Screen (file name) | Look at |
|---|---|
| 01 main-boss, 03 main-rule, 04 main-daily | top bar chips (stage / coins / level or day chip), rule or boss banner (up to 3 lines), blessing chips wrap to a second line, picks and streak row, item bar hints, bank button two lines |
| toast-peek, toast-shield, toast-boom-crush | toast text fits (up to 3 lines) and does not cover the banner or cards |
| pill-new-record | gold capsule on one line |
| shop-top / scrolled / full-blessings | title, breakdown, next-stage preview, blessing name + tag wrap, price at the right, item cells, footer buttons |
| fail-sheet, result-lose-*, result-win-* | title, six marks row, summary, share text, button rows (two-line labels are fine) |
| difficulty, difficulty-scrolled | six rows, locked rows, long rule text wraps |
| rules-1...4, rules-abandon-confirm | long paragraphs, danger table columns, stage rule list (name column), buttons |
| dash-overview, -daily, -levels, -blessings, -empty, -sample-badge | four tab titles on one line, tiles, record rows (name, number, "next goal" line), tables, calendar day cells |
| onboarding-1...6 | callout card text fits above or below the circled area, buttons visible |

## C. Language behaviour (any simulator or device)

1. Settings > General > Language & Region: set each of the six languages in turn (Chinese: Traditional Chinese Taiwan, Traditional Chinese Hong Kong, Simplified Chinese). Launch: home screen name and all text are in that language. A language the app does not have (for example French) shows English.
2. Home screen app name per language: en `Intuition++`, ja `選ばれし者++`, ru `Интуиция++`, zh-Hans `天选之子++`, zh-Hant and zh-HK `天選之人++`.
3. Day chip and share text date: en and zh `11/16`, ja `11/16`, ru `16.11`, zh-HK `16/11`.
4. Numbers: ru groups with a space (`1 040`), en / ja / zh with a comma (`1,040`); decimals follow the language (`×1,5` in Russian).
5. Share text (result sheet, "Copy result"): paste it into Notes. The emoji grid and numbers are unchanged; the words are in the app language.
6. Records page, "Old records" link (legacy): title, date and labels are localized (the six legacy keys).
7. Russian plural forms: records page, Daily tab, streak tile `1 день / 2 дня / 5 дней` (and the `+N endless stages` tile in en: `+1 endless stage`, `+2 endless stages`).
8. VoiceOver in one non-Chinese language: card, bank button, item bar and shop rows read full sentences in that language, joined with that language's comma.
9. Dynamic Type is not changed by this phase (fixed font sizes, as before).

## D. App Store assets

- `docs/redesign/store/<locale>.md`: read each language once. zh-Hans is converted from zh-Hant with mainland vocabulary; zh-HK follows zh-Hant with a few Hong Kong terms. ja and ru are written, not translated word by word.
- `docs/redesign/store/screenshots/<locale>/`: five PNGs of 1320 x 2868, status bar 9:41 with a full battery, no test-ad banner.
- `docs/redesign/store/release-checklist.md`: the owner's list before submitting.
