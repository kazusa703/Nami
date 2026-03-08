# CLAUDE.md - Nami（波）

## プロジェクト概要

**アプリ名:** Nami（波）
**コンセプト:** 気分を記録し、生活習慣との相関からアクショナブルな気づきを提供するムードトラッキングアプリ
**プラットフォーム:** iPhone（iPad非対応）+ Apple Watch + ウィジェット
**最低サポート:** iOS 17.0+
**言語:** Swift / SwiftUI
**開発環境:** Xcode（最新安定版）
**ローカライズ:** 日本語（デフォルト）・英語
**Bundle ID:** `com.imai.Nami`
**App Group:** `group.com.imai.Nami`
**iCloud Container:** `iCloud.com.imai.Nami`

---

## コア体験

アプリを開く → スコアを1タップで記録 → タグで感情を分類 → 閉じる。この**5秒の体験**が核。
記録が積み重なると:
- 点が線で結ばれ、**気分の波（ライングラフ）**が見える
- AIインサイトが**曜日・タグ・天気・ヘルスケアとの相関**を自動発見
- **今日のアクション提案**（DailyTip）で何をすべきか分かる

---

## 現在の機能仕様

### 1. 気分記録（MainView）
- スコア入力: ボタングリッド（1-30）またはスライダー（31+）
- スコア範囲: 1-10 / 1-100 / -10-10（月1回変更可、30日クールダウン）
- RecordingSheet: 4タブ（タグ→メモ→写真→ボイス、デフォルトはタグ）
- 記録時に天気データ自動付与（PRO、非同期）
- ウィジェット記録バナー + 今日のヒント表示（20件以上）

### 2. グラフ（GraphView）
- 3モード: 折れ線 / 棒グラフ / 芝生（YearInPixels）
- DateRangeCalendarPicker: プリセット（1日/1週/1月/3月/1年）+ カスタム
- フルスクリーン表示（横画面対応、ZStackオーバーレイ方式）
- ドリルダウン: 年→月→日→時間
- タップで記録詳細表示、メモ編集、削除

### 3. 統計（StatsView）— 19セクション
セクション順序（上から）:
1. 今日のヒント（DailyTip、最大3件）
2. AIインサイトカルーセル（13種 + Premium 3種、日替わり最大5枚）
3. ヘルスケア×気分（歩数/睡眠/運動量）
4. 天気×気分（天気/気温/気圧）
5. 週間レビュー
6. 月間レビュー（MonthlyHeatmap）
7. 生活リズム（時間帯別）
8. サマリーカード（SNSシェア可能）
9. スコア分布
10. 平均スコア
11. 過去比較
12. 曜日別平均
13. 時間帯別
14. ストリーク
15. カレンダーヒートマップ
16. タグ分析
17. プレミアム分析
18. 発見セクション
19. アクティビティ

### 4. 設定（SettingsView）
- テーマ: Ocean / Lavender / Mono Gold / Forest
- 記録設定: スコア範囲、入力方式、ハプティクス
- 感情タグ管理（TagManagementView）: Built-in 15 + Custom（PRO: 無制限、Free: 20個）
- 天気自動記録（PRO、CoreLocation + WeatherKit）
- ヘルスケア連携（HealthKit: 歩数/睡眠/運動量）
- リマインダー通知（ローカル通知、デフォルト21:00）
- ウィジェット管理
- データ: CSVエクスポート / 全削除
- iCloud同期ステータス
- プレミアム購入（月額/年額/買い切り）
- アプリ情報: プライバシーポリシー / 利用規約 / フィードバック

### 5. ウィジェット
- Small: 最新スコア + スコアボタン
- Medium: トレンドチャート + スコアボタン
- Large: 統計カード + スコアボタン
- LockScreen: 円形ゲージ / 長方形 / インライン
- RecordMoodIntent でウィジェットから直接記録

### 6. Apple Watch
- WatchMainView: スコア入力
- WatchTagSelectionView: タグ選択
- WCSession 経由で iPhone と双方向同期

---

## データモデル（SwiftData + iCloud同期）

### MoodEntry (@Model)
```
score: Int, maxScore: Int, minScore: Int
memo: String?, tags: [String]
createdAt: Date, source: String ("app"/"widget"/"watch")
photoPath: String?, voiceMemoPath: String?
weatherCondition: String?, weatherTemperature: Double?
weatherPressure: Double?, weatherHumidity: Double?
latitude: Double?, longitude: Double?
normalizedScore: Double (computed, 0.0-1.0)
```

### EmotionTag (@Model)
```
name: String, icon: String, categoryRaw: String
isDefault: Bool, isActive: Bool
sortOrder: Int, customCategoryId: UUID?
```
Built-in 15タグ: Positive(嬉しい/楽しい/穏やか/感謝/元気) + Negative(不安/疲れた/イライラ/悲しい/ストレス) + Factor(仕事/運動/睡眠不足/人間関係/リラックス)

### TagCategory (@Model)
```
name: String, icon: String, sortOrder: Int
```

---

## 技術スタック

| カテゴリ | 技術 |
|---------|------|
| UI | SwiftUI |
| データ | SwiftData + CloudKit (iCloud sync) |
| グラフ | Swift Charts |
| ウィジェット | WidgetKit + App Groups |
| 広告 | Google Mobile Ads SDK (AdMob) |
| 課金 | StoreKit 2 (monthly/yearly/lifetime) |
| 天気 | WeatherKit + CoreLocation |
| 健康 | HealthKit |
| 通知 | UserNotifications |
| Watch | WatchConnectivity |
| パッケージ | Swift Package Manager |

---

## 収益モデル

### 広告（AdMob）
- バナー広告: グラフ画面・統計画面の下部
- メイン記録画面には非表示

### プレミアム（StoreKit 2）
| プラン | Product ID | 内容 |
|--------|-----------|------|
| 月額 | com.imai.Nami.premium.monthly | 広告除去 + 天気 + 無制限タグ |
| 年額 | com.imai.Nami.premium.yearly | 同上 |
| 買い切り | com.imai.Nami.removeAds | 広告除去のみ |

---

## ビルド情報

- **Simulator:** `iPhone 17 Pro` (OS 26.2) — iPhone 16 シミュレータは存在しない
- **Physical Device:** `00008110-001425820CA0201E` (デバイス名: 本人)
- **Signing:** Apple Development: atsuko imai (JQ3GG4F4BB)
- **ビルドコマンド例:**
  ```bash
  cd /Users/imaiissatsu/Nami && xcodebuild build -scheme Nami -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
  ```

---

## 外部リンク

- **プライバシーポリシー:** https://kazusa703.github.io/nami-support/ja/privacy.html
- **利用規約:** https://kazusa703.github.io/nami-support/ja/terms.html
- 英語版は `/en/privacy.html`, `/en/terms.html`

---

## 注意事項（Claude Code向け）

- **ソースパス:** `/Users/imaiissatsu/Nami/` — `Desktop/Namiのコピー/`はxcodeprojのみでソースなし
- SwiftUI プレビュー: modelContainer + environment(\.themeManager) が必要
- StatsView: LazyVStack + AnyView型消去でスタックオーバーフロー防止（必須パターン）
- HealthBandData: HealthMoodChartViewで共用（Health/Weather両方）
- InsightEngine: enum + static methods（インスタンス不要）
- 天気分類関数: WeatherStatsSection と InsightEngine で重複あり（private scope内なので許容）
- `nonisolated(unsafe)` on InsightEngine.cachedTips: MainActorコンテキスト前提
- コード内コメント: 英語
- ユーザーとの会話: 日本語
