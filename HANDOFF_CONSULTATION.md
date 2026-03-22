# Nami — 技術面・アプリ内容面 相談文

## このドキュメントの目的
Namiアプリの現状について、技術面とアプリ内容面（UX/機能設計）の2つの観点からフィードバック・改善提案をいただきたいです。

---

# 📐 相談1: 技術面

## アプリ概要
**Nami**はiOS向けの気分記録アプリです。1タップでスコアを記録し、タグ・メモ・写真・ボイスメモを付けて、統計やインサイトで自己理解を深めるアプリです。

### 技術スタック
- **言語**: Swift 6 / SwiftUI
- **データ**: SwiftData + CloudKit（iCloud同期）
- **フレームワーク**: HealthKit, WeatherKit, CoreLocation, StoreKit 2, WidgetKit, WatchConnectivity, GoogleMobileAds, NaturalLanguage
- **アーキテクチャ**: MVVM（@Observable, iOS 17+）
- **ターゲット**: iOS 26.2, Xcode 26.3
- **App Group**: `group.com.imai.Nami`（メインアプリ ↔ ウィジェット間データ共有）

### プロジェクト規模
- Swiftファイル: 46ファイル
- メインアプリ: 36ファイル（Models 3, Views 18, ViewModels 4, Utilities 7, Store 1, Theme 2, Ads 1）
- ウィジェット: 10ファイル
- ローカライズ: 日本語（源言語）+ 英語

### データモデル（MoodEntry）
```swift
@Model class MoodEntry {
    var id: UUID = UUID()
    var score: Int = 5              // scoreRangeMin〜maxScore
    var memo: String?               // 任意メモ（最大100文字）
    var createdAt: Date = Date.now
    var maxScore: Int = 10          // 記録時のスコア範囲上限
    var scoreRangeMin: Int = 1      // 記録時のスコア範囲下限
    var photoPath: String?          // App Group内の写真相対パス
    var voiceMemoPath: String?      // ボイスメモの相対パス
    var tags: [String] = []         // タグ名の配列
    var source: String = "app"      // "app", "widget", "watch"
    var energyLevel: Int? = nil     // 1=低, 2=普通, 3=高
    var weatherCondition: String? = nil  // "sunny","cloudy","rainy"等
    var weatherTemperature: Double? = nil // 摂氏
}
```

### タグモデル（EmotionTag）
```swift
@Model class EmotionTag {
    var name: String = ""
    var categoryRaw: String = "custom"  // positive/negative/factor/location/activity/social/custom
    var icon: String = "tag.fill"
    var isDefault: Bool = false
    var sortOrder: Int = 0
}
```
**注意点**: `MoodEntry.tags`は`[String]`で保存（SwiftData Relationship不使用）。タグ名変更時に過去データとの不整合リスクあり。現在はタグ名変更機能を意図的に見送り、削除+再作成で対応。

### スコア範囲
8パターンのプリセット（pos10/30/50/100, neg10/30/50/100）。ネガティブ範囲（-10〜10等）にも対応。`normalizedScore`（0.0-1.0）で異なるレンジ間を正規化比較。

### 課金（StoreKit 2）
3プラン構成（すべてApp Store Connectで審査通過済み）:
- 月額: `com.imai.Nami.premium.monthly` ($4.99)
- 年額: `com.imai.Nami.premium.yearly` ($29.99)
- 買い切り: `com.imai.Nami.removeAds` ($49.99)

`PremiumManager`で3プラン対応済み。`isPremium`で全機能ゲートを一元管理。サブスクは`Transaction.currentEntitlements`で有効期限+取り消しチェック。

### iCloud同期
- SwiftData: `cloudKitDatabase: .automatic`で自動同期
- 写真: iCloud Documents（`NSUbiquitousContainerURL`）にバックグラウンドコピー。`NSFileCoordinator`で信頼性確保
- ウィジェット: `cloudKitDatabase: .none`（ローカルのみ書き込み）

### 天気自動記録
`WeatherManager`（@Observable）がCoreLocation + WeatherKitで記録時に自動取得。`CLLocationManager`のdelegateは`nonisolated`メソッドから`Task { @MainActor in }`でメインアクターに戻すパターン。

### HealthKit連携
歩数・睡眠・安静時心拍数を読み取り、気分スコアとのPearson相関を計算。設定でON/OFF切替。`HKStatisticsQuery`と`HKSampleQuery`を`withCheckedContinuation`でasync化。

### 統計・分析エンジン
- **StatsViewModel**: 20+のメソッド（曜日別平均、時間帯別、タグ分析、ボラティリティ、回復パターン、メモキーワード分析（NLTokenizer）、天気相関、エネルギー乖離、安定度スコア等）
- **InsightEngine**: 16種のインサイト自動生成（日付ベースローテーション）
- **PredictionEngine**: 曜日傾向(0.4) + トレンド(0.3) + タグパターン(0.3)の加重平均で明日のスコア予測（プレミアム限定）

### グラフタブ
- **GraphMode**: 折れ線 / ヒートマップ（棒グラフは削除済み）
- **DateSelectionMode**: 日/週/月/年の4段階
- **FullscreenChartView**: ピンチズーム+ドラッグパンで自由に閲覧。10段階のX軸ストライド最適化
- **PlotDay+segmentId**: 記録がない日でLine/AreaMarkが途切れるよう、セグメントIDで分離

### ウィジェット
- Small/Medium/Large/LockScreen対応
- Interactive: `AppIntent`ベースのスコアボタンで直接記録
- 過去記録のランダム表示機能

## 技術面で相談したいこと

### 1. SwiftData + CloudKit のスケーラビリティ
現在のデータモデルで1年間毎日3回記録すると約1,000エントリ。5年で5,000エントリ。この規模で`@Query(sort: \MoodEntry.createdAt, order: .reverse)`を全ビューで使っているが、パフォーマンス問題は出るか？`FetchDescriptor`で期間フィルタした方がいいか？

### 2. `MoodEntry.tags: [String]`の設計判断
タグをRelationshipではなく文字列配列で保存した理由はCloudKit互換性とシンプルさ。しかし、タグ名変更・統計のクロスリファレンス・タグの一意性保証が弱い。今からRelationship化すべきか？それとも現状の「タグ名変更禁止 + 削除/再作成」で実用上十分か？

### 3. StatsView の肥大化
`StatsView.swift`が約3,500行に膨らんでいる。26セクションを1ファイルで管理。セクションごとに別ファイルに分割すべきか？その場合、`@Query`や`@Environment`の共有方法として何が最適か？

### 4. async/awaitとMainActor
HealthKitManager、WeatherManagerのクエリは`@MainActor`クラス内で`withCheckedContinuation`を使用。HKQueryのコールバックは非MainActorスレッドから呼ばれるので、continuation.resume()はデータ競合リスクなし（Sendable値を返すため）だが、この設計で問題ないか？

### 5. ウィジェットとメインアプリのデータ整合性
ウィジェットは`cloudKitDatabase: .none`で書き込み、メインアプリは`.automatic`で読み書き。ウィジェットで記録→メインアプリで読み取り→iCloud同期の流れで、App Group共有ストアファイルの同時アクセスによる破損リスクはあるか？

### 6. メモリ管理
`StatsViewModel`はビューの`@State`として保持され、20+のメソッドで`entries: [MoodEntry]`配列を受け取って毎回計算。キャッシュは`@State`変数で`entries.count`変更時に再構築。このパターンで5,000エントリ時にメモリ圧迫しないか？

---

# 🎨 相談2: アプリ内容面（UX / 機能設計 / マネタイズ）

## アプリの現状

### コンセプト
「1タップで気分を記録し、パターンを発見して自己理解を深める」メンタルヘルス日記アプリ。ターゲットは20-40代の日本語ユーザー。

### 画面構成（5タブ）
1. **記録タブ** — スコア入力（ボタングリッド or スライダー）+ ストリークバッジ + 最新記録表示。記録後にシート表示（メモ / タグ / 写真 / ボイスメモ / エネルギーレベル）
2. **グラフタブ** — 折れ線グラフ + ヒートマップ。日/週/月/年切替。全画面表示（ピンチズーム対応）。タップで日詳細（24時間タイムライン）
3. **統計タブ** — 26セクション: インサイト、週間レビュー、ムードリズム、サマリーカード、分布、平均、過去比較、曜日別、時間帯別、ストリーク、カレンダー、タグ分析、メモキーワード、記録元別、記録タイミング、安定度、天気相関、エネルギー相関、場所分析、回復パターン、HealthKit相関、予測（PRO）、タグ遷移マップ（PRO）、プレミアム分析、発見、アクティビティ
4. **PROタブ** — プレミアム機能紹介 + 3プラン選択ペイウォール
5. **設定タブ** — テーマ、記録設定（スコア範囲、入力方式）、タグ管理、リマインダー、ウィジェットガイド、データ管理（CSV出力 / 全削除）、ヘルスケア連携、iCloud同期、プレミアム状態

### 記録時に収集するデータ
| データ | 入力方法 | 必須 |
|--------|----------|------|
| スコア | ボタン or スライダー | ✅ |
| メモ | テキスト入力 | ❌ |
| タグ | カテゴリ別チップ選択 | ❌ |
| 写真 | カメラ or ライブラリ | ❌ |
| ボイスメモ | 録音 | ❌ |
| エネルギー | 3段階アイコン | ❌ |
| 天気 | 自動取得 | 自動 |
| 場所 | 場所タグ（自宅/職場等） | ❌ |

### プレミアム機能（PRO限定）
- 広告非表示
- カスタムタグ無制限（無料は10個まで）
- スコア予測（明日の気分予測）
- タグ遷移マップ（タグ間の影響フロー図）
- 高度分析（タグチェーン、エコー効果、乖離アラート、回復トリガー、シナジー）
- 月間レポートカード（SNSシェア画像生成）

### 無料ユーザーが使える機能
- 全スコア記録機能
- メモ・写真・ボイスメモ・エネルギー記録
- タグ（デフォルト27個 + カスタム10個まで）
- 基本統計（インサイト、週間レビュー、分布、平均、曜日/時間帯、ストリーク、カレンダー、天気相関、安定度）
- グラフ（折れ線 + ヒートマップ + 全画面）
- ウィジェット（全サイズ）
- Apple Watch対応
- iCloud同期
- HealthKit連携
- CSV出力

## アプリ内容面で相談したいこと

### 1. 統計タブの情報過多
26セクションは多すぎないか？ユーザーが「何を見ればいいかわからない」状態になっていないか？優先度の高いセクションを上に、低いものは折りたたみ or プレミアムに隠すべきか？

### 2. 無料 vs プレミアムの線引き
現在、無料でかなり多くの機能を使える。プレミアムの訴求力が弱い可能性。以下のどちらが良いか？
- A: 現状維持（無料で十分使える→一部ユーザーがPRO購入）
- B: 無料機能を絞る（例: 統計の一部をPRO限定に）→ コンバージョン向上だがレビュー低下リスク

### 3. 記録の継続率（リテンション）
現在の継続施策：ストリークバッジ + マイルストーン + リマインダー通知。他に効果的な施策は？
- 低スコア時のセルフケア提案？
- タグ目標（「運動タグを週3回」等）？
- 週間サマリーのプッシュ通知？

### 4. オンボーディングの改善
現在は4ステップ（ウェルカム → テーマ → スコア範囲 → 通知）。タグの説明やエネルギーレベルの説明がない。初回記録後に「タグを付けてみましょう」のようなガイドを出すべきか？

### 5. スコア範囲の選択肢が多すぎないか
8パターン（pos10/30/50/100 + neg10/30/50/100）はユーザーを混乱させないか？実際のユーザーは何を選ぶことが多いか？デフォルト（1-10）で十分なユーザーが大半なら、他は「詳細設定」に隠すべきか？

### 6. 競合との差別化ポイント
Daylio、Bearable、How We Feel、Finchと比較して、Namiの独自性は何か？「タグの翌日効果分析」「タグ遷移マップ」「天気自動相関」は競合にない要素だが、ユーザーに伝わっているか？App Storeの説明文やスクリーンショットでどう訴求すべきか？

### 7. マネタイズの最適化
月額$4.99 / 年額$29.99 / 買い切り$49.99の価格設定は適切か？競合のDaylioは年額$20前後。プレミアム機能の内容に対して高い/安いの判断は？初回特別価格や無料トライアルは導入すべきか？

### 8. SNSシェア機能の活用
月間レポートカードのSNSシェア機能がある。シェアを促すUXとして何が効果的か？シェア画像にアプリ名のウォーターマークは入れているが、App Storeリンクは含めるべきか？

---

## 補足情報
- App Store審査は1度通過済み（上記3プランすべて承認済み）
- 開発者は個人（ソロ開発）
- 主要マーケット: 日本（英語ローカライズ済み）
- 現在のApp Storeカテゴリ: ヘルスケア/フィットネス
