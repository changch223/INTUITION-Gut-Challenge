# 04 實作計畫

## 1. 現況

- SwiftUI，iOS 17.6 以上，Swift 5，CocoaPods（Google Mobile Ads）。
- 主要檔案：`ContentView.swift`（整個畫面）、`GameLogic.swift`（50/50 規則）、`GameRecord.swift`（每日最佳分數）、`LuckLevel.swift`（15 級稱號）、`DailyRecordsView.swift`、`LuckLevelStandardsView.swift`。
- 可沿用的服務：`AudioManager.shared.playSound(_:)`、`HapticManager.shared.playSuccess/playError/playClick`、`RewardedAdManager.shared.showAd(from:reward:)`、`BannerAdView(adUnitID:)`、`AppOpenAdManager`。
- 語系：en、ja、ru、zh-Hans、zh-Hant、zh-HK。

## 2. 建議的檔案結構

```
BoomOrBonus/
  Engine/                    ← 不 import SwiftUI，可單元測試
    Rng.swift                Mulberry32、seedOf
    Rules.swift              常數、祝福／魔王／特殊規則／難度的定義
    RunState.swift           Card、RunState、Phase、BlessingID 等型別
    GameEngine.swift         newRun、genPair、deltaOf、pickCard、canClear、rewardParts、clearStage、failStage、nextStage
    Shop.swift               shopOffer、buyBlessing、buyItem、price
  Store/
    SaveStore.swift          SaveData 讀寫、開新局、恢復進行中的局
    DailyRecord.swift        今日挑戰紀錄與衍生數字
    Stats.swift              累計數字、個人紀錄、里程碑
  Game/
    GameViewModel.swift      @Observable：持有 RunState，負責流程、動畫時序、音效、觸覺、存檔
  Views/
    GameScreen.swift         主畫面組合
    TopBar.swift  RuleBanner.swift  ScorePanel.swift  PicksStreakRow.swift  BlessingChips.swift
    CardView.swift           含引信、蓋住的牌、透視標籤、揭曉動畫
    ItemBar.swift  BankButton.swift  ToastView.swift  RecordPopView.swift
    Sheets/ShopSheet.swift  FailSheet.swift  ResultSheet.swift  RulesSheet.swift  DifficultySheet.swift
    Dashboard/DashboardSheet.swift  OverviewTab.swift  DailyTab.swift  LevelsTab.swift  BlessingsTab.swift
    Onboarding/CoachMarkOverlay.swift
BoomOrBonusTests/
  RngTests.swift  EngineVectorTests.swift  EngineRuleTests.swift  DailyRecordTests.swift  StatsTests.swift
```

`test-vectors.json` 加進測試 target 的資源。

## 3. 分階段任務

每個階段都能單獨合併。驗收標準由另一個人或審查用的模型檢查，不由實作者自己驗收。

### 第 0 階段：修現有版本的問題（可選，只有在新版上線前要先發一版時才做）

- 機率說明頁寫減法 10%、乘法 30%，程式實際是各 20%。
- 深色模式下文字可能白字白底（請在實機確認）。
- iPhone 允許橫向，改成只允許直向。
- 每日紀錄沒有排序。
- 橫幅廣告緊貼操作按鈕。

**驗收**：上述五項在實機逐一確認。

### 第 1 階段：規則引擎與亂數

- 實作 `Engine/` 的全部內容，行為與 `reference/core.js` 一致。
- 測試：
  - `RngTests`：`mulberry32`、`seedOf` 與測試向量完全一致。
  - `EngineVectorTests`：`nice`、`targets`、`stageRule`、`genPair_*`、`shopOffer_*`、`stagePicks` 全部與測試向量一致。
  - `EngineRuleTests`：至少涵蓋
    - 保命符擋下時不扣手數、連中保留；
    - 拆彈每關只生效一次；
    - 不屈：連中 1 → 1、4 → 2、5 → 3；
    - 重壓只砍這關分數，`total` 不變；
    - 未選任何一手時不能過關；
    - 利息用拿獎勵前的金幣計算；
    - 第 6 關過關得到 `win`，`endless = true` 時得到 `shop`；
    - 連中跨關不歸零；
    - 祝福上限 5 個，可重複祝福疊層不佔格；
    - 傳說難度價格 +$1、基本獎勵 $2。

**驗收**：所有測試通過；引擎檔案沒有 import SwiftUI；沒有使用系統亂數。

### 第 2 階段：主畫面與一手的流程（只做自由練習、入門難度）

- 主畫面全部元件（`02-screens-ux.md` 第 2 節）。
- 選一手的流程與時間（第 3 節）、提示（第 6 節）。
- 過關按鈕的兩種狀態與金幣明細。
- 手數用完的失敗面板（廣告先用模擬，2.5 秒後回呼）。
- 簡易結算面板（總分、戰績格、再來一局）。
- 固定直向、Reduce Motion 支援、VoiceOver 標籤。
- 每一手後存檔，重開 App 能接著玩。

**驗收**：用固定種子開局時，畫面上的牌與測試向量一致；動畫中連點不會重複選牌；殺掉 App 再開能回到同一手。

### 第 3 階段：商店、祝福、魔王、特殊規則、無盡關卡、難度

- 商店面板（第 4 節），含換一批、道具購買、下一關預告。
- 十個祝福、四個魔王、八條特殊規則的效果與畫面呈現（規則橫條、蓋住的牌）。
- 破關後的無盡關卡。
- 選擇難度面板、解鎖流程、結算面板的完整按鈕組合（第 5.2 節）。

**驗收**：每個祝福、魔王、規則各有一個 UI 測試或手動測試步驟；解鎖只在前 6 關全過時發生。

### 第 4 階段：今日挑戰

- 模式切換、兩個模式各自保留進行中的局。
- 日期種子、第幾次挑戰、`DailyRecord` 的更新規則（`03-data-persistence.md` 第 3 節）。
- 放棄算一次挑戰；過午夜作廢昨天的局。
- 複製戰績文字。

**驗收**：兩台裝置在同一天開今日挑戰，前 5 手的牌一樣；放棄後 `tries` +1；破關後 `winTry` 正確；跨日後開新的一天。

### 第 5 階段：說明與新手導覽

- 六步新手導覽（第 7 節），遮罩挖空位置在不同螢幕尺寸都對準。
- 規則面板（第 8 節）。
- 所有「說明寫在操作位置」的元素都已到位：進度條標籤、過關按鈕小字、道具小字、保命符說明、爆炸與擋下的牌面小字。

**驗收**：從 iPhone SE 到 Pro Max，導覽的框都對準目標；第一次開啟自動出現，完成後不再出現。

### 第 6 階段：我的紀錄

- `Stats`、個人紀錄、里程碑（`03-data-persistence.md` 第 4 節）。
- 新紀錄提示與結算面板的「這局打破 N 項紀錄」。
- 紀錄頁四個分頁與空狀態、範例資料（`02-screens-ux.md` 第 10 節）。

**驗收**：第一局不跳新紀錄；同一項一局只跳一次；日曆與柱狀圖在 SE 尺寸不被擠壓；範例資料明確標示。

### 第 7 階段：廣告、在地化、上架準備

- 接上真的獎勵廣告與插頁廣告（第 12 節），橫幅只放在商店與結算面板。
- 六個語系的文案。專有名詞照 `README.md` 的名詞表。
- 音效補齊（第 13 節）。
- App Store 截圖與說明更新。

**驗收**：廣告載入失敗時不卡住流程；六個語系沒有截斷或遺漏的字串。

## 4. 委派建議

這個專案使用 cc-crew 的分工：

| 階段 | 實作 | 審查 |
|---|---|---|
| 1 | builder：照 `01-game-rules.md` 與 `core.js` 移植，寫測試 | qa-reviewer：逐條對照 `core.js`，跑測試向量 |
| 2～6 | builder：每階段一個任務，附上對應章節 | qa-reviewer：照該階段驗收標準檢查，在模擬器實際操作 |
| 7 | builder | qa-reviewer，之後交給 shipper 出版 |

給 builder 的任務描述建議包含：目的、要讀的章節（本資料夾的檔名與節號）、限制（不改常數、不用系統亂數、引擎不 import SwiftUI）、要交回的東西（diff 與測試結果）。

## 5. 待決事項

| 問題 | 選項 | 目前建議 |
|---|---|---|
| 舊版每日紀錄怎麼處理 | 刪除／保留但不顯示／在紀錄頁放「舊版紀錄」連結 | 保留，放連結 |
| 原本的 15 級分數稱號 | 廢除／依新總分重新校準 | 先用過關數對應 7 個稱號，上線後依真實分數分佈重新校準 |
| 今日挑戰的時區 | 使用者本地時區／統一 UTC | 本地時區（符合「今天」的直覺）；若要做全球排行榜再改 UTC |
| 字體 | 打包 Bricolage Grotesque 與 Noto Sans TC／用系統字體 | 數字用 Bricolage Grotesque，內文用系統字體，減少檔案大小 |
| 「不屈」的替代設計 | 現行的減半無條件進位／每關第一次爆炸時連中不歸零 | 先用現行版本，看祝福破關率再決定 |
| 「進階」和「入門」差距 | 目標 ×1.15／更高 | 先用 ×1.15，看真實破關率 |

## 6. 已知限制

- 所有平衡數字都是模擬結果。模擬不用道具、不會依魔王換策略，濃霧也只用平均值估，真人的表現可能差很多。上線後應該用「我的紀錄」的資料（各關過關率、祝福破關率）重新調整。
- 原型只做過語法檢查與規則的自動測試，畫面沒有完整的實機測試。
- 原型的廣告、分享都是模擬：分享只複製文字，正式版可以改用系統分享面板。
