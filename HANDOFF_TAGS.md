# Nami タグ追加UIの改善 — 相談文

## プロジェクト概要
- **アプリ名**: Nami（気分記録アプリ）
- **技術**: SwiftUI + SwiftData / Xcode 26.3 / iOS 26.2 / Swift 6
- **プロジェクトパス**: `/Users/imaiissatsu/Projects/Nami`

## 背景

タグはこのアプリの重要機能。気分スコアに加えてタグを付けることで「運動した日はスコアが高い」「一人の日は低い」等の分析が可能になる。

### 現在のタグカテゴリ（7種）
| カテゴリ | rawValue | 表示名 | アイコン | デフォルトタグ例 |
|---------|----------|--------|---------|----------------|
| positive | "positive" | ポジティブ | sun.max.fill | 嬉しい、楽しい、感謝 |
| negative | "negative" | ネガティブ | cloud.rain.fill | 悲しい、不安、イライラ |
| factor | "factor" | 要因 | leaf.fill | 運動、仕事、天気 |
| location | "location" | 場所 | mappin.and.ellipse | 自宅、職場/学校、外出先、移動中 |
| activity | "activity" | 活動 | figure.walk | 読書、料理、散歩、買い物 |
| social | "social" | 人 | person.2.fill | 一人、家族、友人、同僚 |
| custom | "custom" | カスタム | star.fill | （ユーザー作成） |

### 無料/プレミアムの制限
- **無料**: カスタムタグ10個まで
- **プレミアム**: 無制限

## 現状のUI（2箇所）

### 1. 設定タブ — タグセクション（設定リストの最上部）
**ファイル**: `Nami/Views/SettingsView.swift` 357-497行

構成：
- **クイックタグ追加**（インライン入力）: テキストフィールド + カテゴリメニュー + 追加ボタン
- **エラー表示**: 重複・上限時に3秒表示
- **カスタムタグ一覧**: FlowLayoutでチップ表示（カスタムタグのみ）
- **タグ管理リンク**: NavigationLinkでTagManagementViewへ

```swift
// クイックタグ追加のインラインUI
HStack(spacing: 8) {
    Image(systemName: "plus.circle.fill")
    TextField("新しいタグを入力...", text: $quickTagName)
    Menu { /* カテゴリ選択 */ } label: { /* アイコン */ }
    Button("追加") { addQuickTag() }
}
```

### 2. タグ管理画面（フル管理）
**ファイル**: `Nami/Views/TagManagementView.swift` 全244行

構成：
- カテゴリ別にセクション分けしたList
- 各タグ行: アイコン + 名前 + デフォルトバッジ
- デフォルトタグはスワイプ削除不可
- 「カスタムタグを追加」ボタン → AddTagSheetモーダル

### 3. AddTagSheet（タグ追加シート）
**同ファイル内** 150-234行

構成：
- タグ名テキストフィールド（自動フォーカス）
- カテゴリ選択（7カテゴリのリスト、チェックマーク）
- 重複チェック
- `.presentationDetents([.medium])`

## データモデル
**ファイル**: `Nami/Models/EmotionTag.swift`

```swift
@Model
class EmotionTag {
    var id: UUID = UUID()
    var name: String = ""
    var categoryRaw: String = "custom"
    var icon: String = "tag.fill"
    var isDefault: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date.now

    var category: EmotionTagCategory {
        get { EmotionTagCategory(rawValue: categoryRaw) ?? .custom }
        set { categoryRaw = newValue.rawValue }
    }
}
```

MoodEntryでの使い方: `tags: [String]` — タグ名を文字列配列で保存（SwiftData relationship不使用）

## ユーザーからの要望

> 「ユーザーがオリジナルのタグを作りやすいようにして」

現在の課題：
1. **クイックタグ追加のカテゴリ選択が分かりにくい** — 小さなアイコンメニューで、初見では何を選べるかわからない
2. **AddTagSheetが地味** — テキストフィールドとリストだけで、タグ作成のモチベーションが湧かない
3. **カスタムタグ一覧が設定タブだけ** — 記録時（RecordingSheet）ではカテゴリ別に表示されるが、自分で作ったタグが見つけにくい
4. **アイコン選択ができない** — カスタムタグのアイコンはカテゴリのアイコンか星が固定。ユーザーがアイコンを選びたい

## 改善方針

以下を改善してほしい（機能の追加ではなく、既存UIの改善）：

### A. クイックタグ追加の改善
- カテゴリ選択をもっと直感的に（メニューではなく横スクロールチップなど）
- 入力時にサジェスト（既存タグとの類似チェック）があると良い
- 追加成功時のフィードバックを強化（アニメーション等）

### B. AddTagSheetの改善
- アイコンピッカーの追加（SF Symbolsから人気のアイコンを20-30個選択可能に）
- プレビュー表示（作成するタグがどう見えるかリアルタイムプレビュー）
- カテゴリ説明の追加（「ポジティブ: 良い気分の時に」等の短い説明）

### C. タグ管理画面の改善
- ドラッグ&ドロップで並び替え対応
- カスタムタグの編集（名前変更、カテゴリ変更、アイコン変更）

## 関連ファイル一覧

| ファイル | 役割 |
|---------|------|
| `Nami/Models/EmotionTag.swift` | タグデータモデル（@Model） |
| `Nami/Models/DefaultTags.swift` | デフォルトタグのシード |
| `Nami/Views/SettingsView.swift` (357-497行) | 設定タブのタグセクション |
| `Nami/Views/TagManagementView.swift` | タグ管理画面 + AddTagSheet |
| `Nami/Views/Components/TagSelectionView.swift` | 記録時のタグ選択UI |
| `Nami/Views/Components/FlowLayout.swift` | タグチップの折り返しレイアウト |
| `Nami/Store/PremiumManager.swift` | `canCreateCustomTag()`, `remainingCustomTags()` |

## ビルド・テスト

```bash
# シミュレータビルド
cd /Users/imaiissatsu/Projects/Nami
xcodebuild -scheme Nami -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# 実機ビルド（iPhone 14 "本人"）
xcodebuild -scheme Nami -destination 'id=00008110-001425820CA0201E' build
```

## 注意事項
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`（Swift 6設定）
- SourceKitがSwiftData `@Model`マクロで偽エラーを出すが、xcodebuildが通れば無視
- `PBXFileSystemSynchronizedRootGroup` — ファイルをNami/フォルダに置けば自動認識
- `EmotionTag`の`icon`プロパティはSF Symbols名を文字列で保持
- タグは`MoodEntry.tags: [String]`に名前の文字列配列で保存される（リレーション不使用）
- **機能の追加ではなくUX改善がメイン** — タグ作成の導線と体験を良くする
