# 03 資料與存檔

## 1. 一局的狀態 `RunState`

對應原型 `core.js` 的 `newG()`。建議做成 `Codable` 的 struct，所有規則函式都以它為輸入。

| 欄位 | 型別 | 說明 |
|---|---|---|
| `version` | Int | 存檔格式版本，目前 6。讀到不同版本的進行中局就丟掉重開 |
| `seed` | UInt32 | 今日挑戰是 `YYYYMMDD`，自由練習是隨機數 |
| `lv` | Int (0…5) | 難度，今日挑戰固定 0 |
| `targetMul` (`tm`) | Double | 今日挑戰 1.3，自由練習 1 |
| `mode` | enum `daily / free` | |
| `day` | Int | 開局那天的 `YYYYMMDD` |
| `attempt` (`try`) | Int | 今日挑戰的第幾次挑戰，自由練習不用 |
| `stage` | Int | 目前關卡，從 1 開始 |
| `value` | Int | 這關目前的分數 |
| `picks` | Int | 這關剩幾手 |
| `stagePicksAtStart` (`sp`) | Int | 這關開始時的手數 |
| `idx` | Int | 這關已選幾手（發牌種子用） |
| `rerolls` (`rr`) | Int | 這一手用了幾次重抽 |
| `shopRerolls` (`srr`) | Int | 這次商店換了幾批 |
| `streak` | Int | 連中，跨關延續 |
| `coins` | Int | |
| `shield` | Int | 保命符數量 |
| `inventory` | `[peek, roll, dbl]: Int` | |
| `blessings` | `[BlessingID: Int]` | 層數 |
| `doubleArmed` (`dbl`) / `peekArmed` (`peek`) | Bool | 雙倍、透視是否啟用中 |
| `defusedThisStage` | Bool | 拆彈本關是否已用 |
| `adUsed` | Bool | 這局是否已看過續命廣告 |
| `marks` | [Int] | 每關結果：2 超標、1 過關、0 失敗 |
| `total` | Int | 已結算各關分數加總 |
| `pair` | [Card] | 目前這手的兩張牌（存起來，才能原樣恢復） |
| `shopOffer` | [BlessingID?] | 商店貨架，買走的位置是 nil |
| `lastRewardParts` | [(label, amount)] | 剛過關的金幣明細，商店顯示用 |
| `phase` | enum `play / shop / win / over` | |
| `endless` | Bool | 是否已進入無盡關卡 |
| `coinsEarned` | Int | 這局賺到的金幣總和（紀錄用，不扣花費） |
| `brokenRecords` | [RecordID] | 這局打破的紀錄 |
| `newlyUnlockedLevel` | Int? | 這局解鎖的難度 |
| `statsCounted` / `dailyCounted` / `abandoned` | Bool | 避免重複計數 |

`Card`：`danger`（1…4）、`p`（Double）、`op`（`add / mul`）、`n`（Double；加分牌是整數）、`boom`（Bool）、`fog`（Bool）。

## 2. 存檔 `SaveData`

原型存在 `localStorage` 的 `ipp-v6`。iOS 建議存成一個 JSON 檔（Application Support）或 `UserDefaults` 的一個 Data，**每一手結束、每次商店購買、每次換關都寫入**，App 被關掉也能接著玩。

| 欄位 | 說明 |
|---|---|
| `runs.daily` / `runs.free` | 兩個模式各自進行中的局（`RunState`） |
| `daily[YYYYMMDD]` | 每天的今日挑戰紀錄，見第 3 節 |
| `unlock` | 已解鎖的最高難度（0…5） |
| `lastLevel` | 自由練習上次選的難度 |
| `deepest` | 無盡關卡最遠的過關數 |
| `onboardingDone` | 新手導覽是否完成 |
| `muted` | 音效開關 |
| `stats` | 個人紀錄與累計數字，見第 4 節 |

### 2.1 讀取進行中的局

模式的進行中局符合以下條件才恢復，否則開新局：

- 版本相同；
- `phase` 是 `play` 或 `shop`（在商店就重新打開商店）；
- 今日挑戰的局：`day` 必須是今天。過了午夜，昨天沒打完的局作廢，但不算一次挑戰。

### 2.2 開新局

- 今日挑戰：`seed = 今天`，`lv = 0`，`tm = 1.3`，`attempt = (今天的 tries ?? 0) + 1`。
- 自由練習：`seed = 隨機`，`lv = min(lastLevel, unlock)`，`tm = 1`。

## 3. 今日挑戰紀錄 `DailyRecord`

| 欄位 | 說明 |
|---|---|
| `tries` | 已挑戰幾次（含放棄） |
| `win` | 今天是否破關過 |
| `winTry` | 第幾次破關 |
| `total` | 代表成績的總分：破關前是所有挑戰的最高總分；破關後是破關局之中的最高總分 |
| `marks` | 代表成績那一局的戰績格 |
| `hist` | 每一次挑戰的結果 `[{cleared: 過了幾關, total}]`，柱狀圖用 |

更新時機是一局「結束」（`finish`），每局只把 `tries` 加一次、`hist` 加一筆：

```
if 第一次結算這局:
    tries = max(tries, attempt); hist.append({cleared, total}); dailyCounted = true
if 這局破關 且 今天還沒破關過: win = true; winTry = attempt; 代表成績 = 這局
else if 今天還沒破關過 且 這局總分 > 代表總分: 代表成績 = 這局
else if 今天已破關 且 這局也破關 且 總分更高: 代表成績 = 這局
```

破關後選擇繼續無盡關卡，無盡結束時會再呼叫一次結算：不再增加次數，但會更新總分與紀錄。

### 3.1 什麼算一次挑戰

| 情況 | 算不算 |
|---|---|
| 手數用完而失敗（含看完廣告後失敗） | 算 |
| 破關 | 算 |
| 在規則面板按 `放棄（算一次）` | 算，即使一手都還沒選 |
| 切換到自由練習再切回來 | 不算，局會保留 |
| 過了午夜，昨天的局作廢 | 不算 |

### 3.2 衍生數字（紀錄頁用）

- 玩過天數、破關天數、最少幾次破關、平均幾次破關（只算破關的日子）。
- 連續破關天數：從今天往回數連續破關的日子；今天還沒破關時從昨天開始數。
- 最長連續破關天數：往回掃 400 天取最長的一段。

## 4. 個人紀錄與統計 `Stats`

### 4.1 累計數字

| 欄位 | 何時更新 |
|---|---|
| `runs` | 每局第一次結算時 +1（含放棄） |
| `abandons` | 放棄的局 +1 |
| `clears` | 破關的局 +1 |
| `allSuper` | 前六關都超標的局 +1 |
| `picks` | 每一手揭曉時 +1 |
| `safe` | 安全的手 +1 |
| `booms` | 爆炸的手 +1 |
| `shields` | 保命符或拆彈擋下 +1 |
| `byLevel[lv]` | `{runs, clears, best}`，自由練習每局結算時更新 |
| `daily` | `{runs, clears, best}`，今日挑戰每局結算時更新 |
| `byBlessing[id]` | `{runs, wins}`，每局結算時，對這局擁有的每個祝福 +1 |

### 4.2 個人紀錄

每項存 `{value, day}`。數值嚴格大於舊值才算打破。

| id | 名稱 | 何時檢查 | 里程碑 |
|---|---|---|---|
| `total` | 單局最高總分 | 結算 | 100 → 250 → 500 → 800 → 1,200 |
| `stage` | 單關最高分 | 每次過關（過關當下的分數） | 30 → 60 → 100 → 160 → 250 → 400 |
| `pick` | 單手最高得分 | 每次安全 | 10 → 20 → 40 → 80 → 150 |
| `streak` | 最長連中 | 每次安全 | 3 → 5 → 8 → 12 → 16 → 20 |
| `deep` | 最多過關數 | 結算 | 3 → 6 → 8 → 10 → 12 → 15 |
| `coins` | 單局賺到最多金幣 | 結算（過關獎勵加總） | 10 → 20 → 35 → 50 → 80 |

- 打破紀錄時，若之前已有紀錄，而且這局還沒為這項跳過提示，就顯示新紀錄提示，並記到 `brokenRecords`。
- 里程碑進度條：`(目前值 - 上一個里程碑) / (下一個里程碑 - 上一個里程碑)`，下方文字 `下一個目標 X　已達成數 / 總數`。

## 5. 舊資料

現有的 `GameRecordManager` 存的是每天最佳分數。新設計的規則不同，分數不能直接比較。建議：

- 不刪除舊資料；
- 新的紀錄頁從零開始累計；
- 若要保留，可在「我的紀錄」底部加一個「舊版紀錄」連結，用現有的 `DailyRecordsView` 顯示（已排序）。

這是待決事項，見 `04-implementation-plan.md`。
