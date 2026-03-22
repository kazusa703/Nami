# Nami グラフタブ — 期間設定 + 折れ線グラフ表示崩れ相談

## プロジェクト概要
- **アプリ名**: Nami（気分記録アプリ）
- **技術**: SwiftUI + SwiftData + Swift Charts / Xcode 26.3 / iOS 26.2 / Swift 6
- **シミュレータ**: iPhone 17 Pro
- **プロジェクトパス**: `/Users/imaiissatsu/Projects/Nami`

## 相談内容

グラフタブの**2つの問題**について修正をお願いしたい：

### 問題1: 期間の設定UIの改善

**現状のフロー:**
1. グラフタブを開く → コントロールバーに「日/週/月/年」セグメントと日付ナビゲーション（◀ ▶）がある
2. 期間シートを開く → `DateSelectionMode`（日/週/月/年）を選択 → カレンダーで日付を選択 → 「適用」ボタン

**ユーザーからの要望:**
- 期間設定シートの「適用」ボタンの**左に「リセット」ボタン**を追加してほしい。押したら選択中の期間を今日/今週/今月/今年にリセットする
- 左上の「キャンセル」ボタンを「＜（戻る）」ボタンに変更してほしい

**関連コード:**
- 期間設定シートは `GraphView.swift` 内の `periodSettingsSheet` メソッド（もしくは `.sheet` modifier で表示される部分）
- `@State private var dateMode: DateSelectionMode`
- `@State private var targetDate: Date`

---

### 問題2: 折れ線グラフの見た目が崩れないようにする

**2つの表示モード:**

#### A. グラフタブを開いてすぐの通常表示
- `GraphView.body` → `overviewChart()` (週/月/年) または `dayLevelChart()` (日)
- `.frame(maxHeight: .infinity)` で高さを決定
- `chartPlotStyle` は使っていない（padding + frame で制御）

#### B. 全画面表示
- `FullscreenChartView` — `ContentView` の ZStack overlay として表示
- 独自の `domainStart/domainEnd` でX軸ドメインを制御
- ピンチズーム + ドラッグでスクロール可能
- `fullscreenChart()` メソッドで描画

**崩れる可能性のあるポイント:**

1. **データが少ない時（1-2点のみ）**: `LineMark`は`visibleEntries.count > 1`の条件で制御しているが、PointMarkのみの場合にグラフ領域が潰れる可能性がある

2. **X軸ラベルの重なり**:
   - 通常表示の`overviewChart`は`dateMode`に応じて固定ストライドを使用（週/月→日単位、年→月単位）
   - 全画面の`fullscreenChart`は`visibleDuration`に応じて7段階でストライドを動的に切り替え（6時間以下→1時間、1日以下→3時間、...、5年超→年単位）
   - **通常表示側にも同様の動的ストライド制御が必要では？** 特に月表示（31日分）でラベルが重なる

3. **Y軸の範囲**: `yAxisDomain` と `smartYAxisValues` で制御。ネガティブスコアレンジ（-10〜10等）に対応してゼロラインRuleMarkも描画している

4. **segmentIdによる線の分断**: 記録がない日をまたぐとLineMark/AreaMarkが途切れる仕組み（`PlotDay.segmentId`）。segmentCount==1の場合はPointMarkのみ表示

5. **全画面↔通常の遷移時**: `FullscreenChartView`は`ContentView`のZStack overlayとして表示。回転対応あり。`onDismiss`でContentViewに戻る

---

## 主要なコード構造

### ファイル
- `/Users/imaiissatsu/Projects/Nami/Nami/Views/GraphView.swift` — 全体（約1500行）

### 主要な型

```swift
// グラフモード（折れ線 or ヒートマップ）
enum GraphMode: String, CaseIterable {
    case line = "折れ線"
    case heatmap = "ピクセル"
}

// 期間選択モード
enum DateSelectionMode: String, CaseIterable, Identifiable {
    case day = "日"
    case week = "週"
    case month = "月"
    case year = "年"
}

// 日別集約データ
struct DailyData: Identifiable {
    let date: Date
    let entries: [MoodEntry]
    // computed: average, minScore, maxScore, count
}

// プロット用データ（途切れ区間ID付き）
struct PlotDay: Identifiable {
    let date: Date
    let average: Double
    let minScore: Int
    let maxScore: Int
    let count: Int
    let segmentId: Int  // 空白日をまたぐとインクリメント
}
```

### チャート描画メソッド

| メソッド | 用途 | X軸制御 |
|---------|------|---------|
| `dayLevelChart()` | 日モード（24時間タイムライン） | 3時間ストライド固定 |
| `overviewChart()` | 週/月/年モード（日単位集約） | dateMode依存の固定ストライド |
| `dayDetailChart()` | 日タップ後の詳細 | 3時間ストライド固定 |
| `fullscreenChart()` | 全画面（全エントリ） | visibleDuration依存の7段階動的ストライド |

### 通常表示のチャートサイズ制御
```swift
// overviewChart / dayLevelChart 共通
.clipped()
.padding(.top, 12)
.padding(.bottom, 20)
.frame(maxHeight: .infinity)
.padding(.horizontal)
```

### 全画面表示のズーム制御
```swift
// FullscreenChartView
@State private var domainStart: Date  // 初期値: 全エントリの最古日 - 1日
@State private var domainEnd: Date    // 初期値: 全エントリの最新日 + 1日
private let minZoom: Double = 3600.0 * 2      // 最小: 2時間
private let maxZoom: Double = 86400.0 * 365.0 * 10  // 最大: 10年

// ピンチズーム + ドラッグで domainStart/domainEnd を動的に変更
// chartXScale(domain: domainStart...domainEnd) で反映
```

### MoodEntryのスコア関連
```swift
// スコアレンジは8パターン: pos10/30/50/100, neg10/30/50/100
// 例: pos10 = 1〜10, neg10 = -10〜10
@AppStorage("scoreRangeMax") var currentMaxScore: Int = 10
@AppStorage("scoreRangeMin") var currentMinScore: Int = 1
```

---

## 修正してほしいこと

### 1. 期間設定シートの改善
- 「適用」ボタンの左に「リセット」ボタンを追加（期間を今日にリセット）
- 左上の「キャンセル」を「＜」戻るボタンに変更

### 2. 折れ線グラフの表示崩れ防止
以下を確認・修正してほしい：

- **通常表示（overviewChart）**: 月表示でX軸ラベルが重なっていないか。重なるなら`fullscreenChart`のような動的ストライド制御を導入
- **全画面表示（fullscreenChart）**: ズームイン/アウト時にラベルが崩れないか。7段階の閾値が適切か
- **データ0-2件時**: グラフ領域が潰れたり空白にならないか。空の場合のフォールバック表示
- **segmentの途切れ**: 1点のみのsegmentでPointMarkが正しく表示されるか
- **Y軸**: ネガティブレンジ（-10〜10等）でゼロラインとラベルが正しく表示されるか
- **chartPlotStyle**: 必要であればchart内部のpaddingを`chartPlotStyle`で制御して安定させる

### 3. テスト方法
```bash
# シミュレータビルド
cd /Users/imaiissatsu/Projects/Nami
xcodebuild -scheme Nami -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# 実機ビルド（iPhone 14 "本人"）
xcodebuild -scheme Nami -destination 'id=00008110-001425820CA0201E' build

# インストール + 起動
xcrun devicectl device install app --device 00008110-001425820CA0201E <DerivedDataのappパス>
xcrun devicectl device process launch --device 00008110-001425820CA0201E com.imai.Nami
```

## 重要な注意事項
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`（Swift 6設定）
- SourceKitがSwiftData `@Model`マクロで偽エラーを出すが、xcodebuildが通れば無視してOK
- `PBXFileSystemSynchronizedRootGroup`使用 — ファイルをNami/フォルダに置けば自動認識
- GraphView.swiftは約1500行あるので全体を読んでから修正してください
- **機能やUIの追加は不要** — 表示崩れの防止と期間設定UIの改善のみ
