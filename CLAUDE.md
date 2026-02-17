# CLAUDE.md - Nami（波）

## プロジェクト概要

**アプリ名:** Nami（波）
**コンセプト:** 気分を10段階で記録し、人生の波を可視化するムードトラッキングアプリ
**プラットフォーム:** iPhone のみ（iPad非対応）
**最低サポート:** iOS 17.0+
**言語:** Swift / SwiftUI
**開発環境:** Xcode（最新安定版）
**ローカライズ:** 日本語（デフォルト）・英語

---

## コア体験

アプリを開く → 10段階の気分を1タップで記録 → 閉じる。この**3秒の体験**が核。
記録が積み重なると点が線で結ばれ、**自分の人生の波（ライングラフ）**が見える。

---

## 機能仕様

### 1. 気分記録（メイン画面）

- アプリ起動直後に表示される画面
- **1〜10の数字ボタン**を配置（1=最も低い気分、10=最も良い気分）
- タップすると即座に記録される
- 記録時のタイムスタンプを「2026年2月9日 17:20」形式で表示
- **1日の記録回数に制限なし**（何回でも記録可能）
- 記録後、**短いメモ（任意）**を追加できるUIを表示（スキップ可能）
- メモは最大100文字程度

### 2. ライングラフ（波の可視化）

- 記録された気分スコアを**時系列の折れ線グラフ**で表示
- X軸: 時間（左=過去、右=現在）
- Y軸: 気分スコア（1〜10）
- 各点は記録されたタイミングに対応
- 表示期間の切り替え: **1週間 / 1ヶ月 / 3ヶ月 / 6ヶ月 / 1年 / 全期間**
- 点をタップするとその記録の詳細（日時・スコア・メモ）をポップオーバーで表示
- グラフは**Swift Charts**を使用して描画
- スクロール・ピンチズームでグラフを操作可能

### 3. 統計表示

- **週間平均スコア**（今週 / 先週との比較）
- **月間平均スコア**（今月 / 先月との比較）
- **年間平均スコア**
- 記録した合計回数
- 連続記録日数（ストリーク）
- 統計画面またはグラフ画面内のセクションとして表示

### 4. ウィジェット対応（WidgetKit）

- **小サイズ:** 今日の最新スコアと簡易ミニグラフ（直近7日分のスパークライン）
- **中サイズ:** 直近7日間の折れ線グラフ + 今週の平均スコア
- ウィジェットタップでアプリのメイン画面を開く
- WidgetKit + SwiftData の AppGroup 共有でデータ連携

### 5. 設定画面

- **テーマ切り替え**（4種類、詳細は後述のデザインセクション）
- リマインダー通知の ON/OFF と時刻設定（ローカル通知）
- データエクスポート（CSV形式）
- 広告除去の購入（課金）/ 復元
- プライバシーポリシー・利用規約リンク
- アプリバージョン表示
- 言語は端末の設定に従う（アプリ内切替なし）

---

## データ設計

### 保存方式: SwiftData（ローカルのみ）

```
@Model
class MoodEntry {
    var id: UUID
    var score: Int          // 1〜10
    var memo: String?       // 任意メモ（最大100文字）
    var createdAt: Date     // 記録日時
}
```

- CloudKit同期なし（ローカルのみ）
- ウィジェットとのデータ共有は **App Groups** を使用
- SwiftData の ModelContainer を App Group の共有コンテナに配置

---

## デザイン仕様

### テーマシステム

設定画面からテーマを切り替え可能。デフォルトはテーマ1。

| # | テーマ名 | 背景 | アクセント | 雰囲気 |
|---|---------|------|-----------|--------|
| 1 | **Ocean**（デフォルト） | 淡いブルー系グラデーション | ディープブルー | 海・波のイメージ、爽やか |
| 2 | **Lavender** | ラベンダー / 薄紫系 | パープル | 穏やか・癒し |
| 3 | **Mono Gold** | 白黒ベース | ゴールド | ミニマル・高級感 |
| 4 | **Forest** | ソフトグリーン系 | ダークグリーン | 自然・ウェルネス |

### デザイン原則

- **ミニマル & クリーン:** 余計な要素を排除し、気分記録に集中できるUI
- ダークモード・ライトモード両対応（各テーマでそれぞれ対応）
- フォント: システムフォント（SF Pro）を使用、丸みのあるデザイン（`.rounded`）
- 数字ボタンは大きく押しやすいサイズ（最低44pt）
- 記録時に軽いハプティックフィードバック（`.impact(.medium)`）
- 画面遷移はスムーズなアニメーション

### 画面構成

1. **メイン画面（記録画面）** - アプリ起動時のデフォルト
2. **グラフ画面** - 波の可視化
3. **統計画面** - 平均スコア等（グラフ画面と統合してもOK）
4. **設定画面**

- TabViewまたはシンプルなナビゲーションで画面遷移
- メイン画面は最小タップで記録完了を最優先

---

## 収益モデル

### 広告（AdMob）

- **バナー広告:** グラフ画面・統計画面の下部に表示
- **メイン記録画面には広告を表示しない**（コア体験を阻害しないため）
- Google Mobile Ads SDK を SPM（Swift Package Manager）で導入

### アプリ内課金（StoreKit 2）

- **商品:** 広告除去（Non-Consumable / 買い切り）
- 機能制限は一切なし、課金要素は広告除去のみ
- 購入の復元機能を必ず実装
- StoreKit 2 API を使用

---

## 技術スタック

| カテゴリ | 技術 |
|---------|------|
| UI | SwiftUI |
| データ | SwiftData |
| グラフ | Swift Charts |
| ウィジェット | WidgetKit |
| 広告 | Google Mobile Ads SDK（AdMob） |
| 課金 | StoreKit 2 |
| 通知 | UserNotifications（ローカル通知） |
| パッケージ管理 | Swift Package Manager |

---

## ローカライズ

- **日本語（ja）:** デフォルト言語
- **英語（en）:** 第二言語
- `String Catalog`（Xcode 15+の `.xcstrings`）を使用
- すべてのUI文字列をローカライズ対応
- 日付フォーマットは端末のロケールに従う

---

## プロジェクト構成（推奨）

```
Nami/
├── NamiApp.swift                  # App エントリポイント
├── Models/
│   └── MoodEntry.swift            # SwiftData モデル
├── Views/
│   ├── MainView.swift             # メイン記録画面
│   ├── GraphView.swift            # ライングラフ画面
│   ├── StatsView.swift            # 統計画面
│   ├── SettingsView.swift         # 設定画面
│   └── Components/
│       ├── MoodButton.swift       # 1〜10のスコアボタン
│       ├── MoodChart.swift        # Swift Charts グラフ
│       └── MemoInputView.swift    # メモ入力UI
├── ViewModels/
│   ├── MoodViewModel.swift        # 気分記録のロジック
│   └── StatsViewModel.swift       # 統計計算のロジック
├── Theme/
│   ├── ThemeManager.swift         # テーマ管理（@AppStorage）
│   └── ThemeDefinition.swift      # 4テーマの色定義
├── Ads/
│   └── BannerAdView.swift         # AdMob バナー広告のUIViewRepresentable
├── Store/
│   └── StoreManager.swift         # StoreKit 2 課金管理
├── Utilities/
│   ├── HapticManager.swift        # ハプティクス
│   └── NotificationManager.swift  # リマインダー通知
├── Localizable.xcstrings          # ローカライズファイル
└── NamiWidget/
    ├── NamiWidget.swift           # ウィジェットエントリポイント
    ├── SmallWidgetView.swift      # 小ウィジェット
    └── MediumWidgetView.swift     # 中ウィジェット
```

---

## App Store 提出要件

- **Bundle ID:** 事前に Apple Developer Portal で登録
- **App Icon:** 1024x1024px、PNG、透過なし、角丸なし（システムが自動適用）
- **プライバシーポリシー:** 必須（URL を用意）
- **利用規約:** App Store 標準 EULA またはカスタム
- **App Tracking Transparency:** AdMob使用のため ATTrackingManager を実装し、広告トラッキング許可ダイアログを表示
- **スクリーンショット:** 6.7インチ（iPhone 15 Pro Max）と 6.1インチ（iPhone 15 Pro）を用意
- **説明文:** 日本語・英語の両方で用意
- **カテゴリ:** ヘルスケア＆フィットネス or ライフスタイル
- **年齢制限:** 4+（広告あり）

---

## 開発の優先順位

1. **Phase 1（MVP）:** メイン記録画面 + SwiftData 保存 + 基本グラフ表示
2. **Phase 2:** 統計画面 + メモ機能 + テーマシステム
3. **Phase 3:** ウィジェット + リマインダー通知
4. **Phase 4:** AdMob広告 + StoreKit課金（広告除去）
5. **Phase 5:** ローカライズ + App Store 提出準備

---

## 注意事項（Claude Code向け）

- SwiftUI のプレビューが動作するよう、サンプルデータを用意すること
- SwiftData の `@Model` マクロを正しく使用すること
- ウィジェットは別ターゲットとして作成し、App Groups でデータ共有
- AdMob の テスト広告ID を開発中は使用すること（本番IDはリリース時に差し替え）
- StoreKit 2 のテストは Xcode の StoreKit Configuration ファイルで行う
- 全コードにわかりやすいコメントを日本語で記述
- エラーハンドリングを適切に行うこと
- アクセシビリティ（VoiceOver対応）を考慮すること
