//
//  FeatureHelpSheet.swift
//  Nami
//
//  Reusable help sheet component with icon diagrams
//

import SwiftUI

/// A single help item with icon diagram
struct HelpItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let diagram: HelpDiagram?
}

/// Visual diagram type for help items
enum HelpDiagram {
    case iconRow([(icon: String, label: String, color: Color)])
    case steps([(number: Int, text: String)])
    case comparison(left: (icon: String, label: String), right: (icon: String, label: String))
    case scale(labels: [String], colors: [Color])
}

/// Reusable help sheet with visual explanations
struct FeatureHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let items: [HelpItem]
    let accentColor: Color

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(items) { item in
                        helpCard(item)
                    }
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private func helpCard(_ item: HelpItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.title3)
                    .foregroundStyle(accentColor)
                    .frame(width: 32)
                Text(item.title)
                    .font(.system(.headline, design: .rounded))
            }

            // Description
            Text(item.description)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Diagram
            if let diagram = item.diagram {
                diagramView(diagram)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private func diagramView(_ diagram: HelpDiagram) -> some View {
        switch diagram {
        case let .iconRow(icons):
            HStack(spacing: 0) {
                ForEach(Array(icons.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.title3)
                            .foregroundStyle(item.color)
                        Text(item.label)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemGroupedBackground))
            )

        case let .steps(steps):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(steps, id: \.number) { step in
                    HStack(spacing: 10) {
                        Text("\(step.number)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(accentColor))
                        Text(step.text)
                            .font(.system(.caption, design: .rounded))
                    }
                }
            }

        case let .comparison(left, right):
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Image(systemName: left.icon)
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text(left.label)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                VStack(spacing: 4) {
                    Image(systemName: right.icon)
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text(right.label)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemGroupedBackground))
            )

        case let .scale(labels, colors):
            HStack(spacing: 2) {
                ForEach(Array(zip(labels, colors).enumerated()), id: \.offset) { _, pair in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(pair.1)
                            .frame(height: 20)
                        Text(pair.0)
                            .font(.system(size: 8, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Help Content Definitions

enum HelpContent {
    // MARK: Graph Tab Help

    static var graphHelp: [HelpItem] {
        [
            HelpItem(
                icon: "chart.xyaxis.line",
                title: String(localized: "グラフモード"),
                description: String(localized: "折れ線グラフとピクセル表示を切り替えできます。左上のアイコンをタップして切り替えてください。"),
                diagram: .iconRow([
                    (icon: "chart.xyaxis.line", label: String(localized: "折れ線"), color: .blue),
                    (icon: "square.grid.3x3.fill", label: String(localized: "ピクセル"), color: .purple),
                ])
            ),
            HelpItem(
                icon: "calendar",
                title: String(localized: "期間選択"),
                description: String(localized: "日・週・月・年の4つの表示単位を選べます。日付ボタンをタップするとホイールピッカーで期間を変更できます。「リセット」で今日に戻ります。"),
                diagram: .iconRow([
                    (icon: "sun.max", label: String(localized: "日"), color: .orange),
                    (icon: "calendar.badge.clock", label: String(localized: "週"), color: .blue),
                    (icon: "calendar", label: String(localized: "月"), color: .green),
                    (icon: "calendar.badge.exclamationmark", label: String(localized: "年"), color: .purple),
                ])
            ),
            HelpItem(
                icon: "arrow.up.left.and.arrow.down.right",
                title: String(localized: "全画面表示"),
                description: String(localized: "右上の拡大ボタンで全画面チャートを表示。ピンチで拡大縮小、スワイプでスクロールできます。タップでエントリの詳細を確認。"),
                diagram: .steps([
                    (number: 1, text: String(localized: "拡大ボタンをタップ")),
                    (number: 2, text: String(localized: "ピンチで拡大/縮小")),
                    (number: 3, text: String(localized: "データ点をタップで詳細表示")),
                ])
            ),
            HelpItem(
                icon: "hand.tap",
                title: String(localized: "日の詳細"),
                description: String(localized: "グラフ上の日をタップすると、その日の全記録を時系列で表示します。「戻る」で概要に戻ります。"),
                diagram: .comparison(
                    left: (icon: "chart.xyaxis.line", label: String(localized: "概要")),
                    right: (icon: "list.bullet", label: String(localized: "日詳細"))
                )
            ),
            HelpItem(
                icon: "circle.fill",
                title: String(localized: "データポイント"),
                description: String(localized: "丸い点はその日の平均スコア。色はスコアの高低を示します。縦の棒は1日のスコアの範囲（最低〜最高）です。"),
                diagram: .scale(
                    labels: [String(localized: "低"), "", "", "", String(localized: "高")],
                    colors: [.red, .orange, .yellow, .mint, .green]
                )
            ),
        ]
    }

    // MARK: Recording Sheet Help

    static var recordingHelp: [HelpItem] {
        [
            HelpItem(
                icon: "pencil.line",
                title: String(localized: "メモ"),
                description: String(localized: "今の気持ちを自由にメモ。100文字まで。後から統計タブでキーワード分析されます。書かなくてもOK。"),
                diagram: nil
            ),
            HelpItem(
                icon: "tag.fill",
                title: String(localized: "タグ"),
                description: String(localized: "気分に関連するタグを選択。感情・要因・場所・活動・人など7カテゴリ。タグを付けるほど分析の精度が上がります。"),
                diagram: .iconRow([
                    (icon: "sun.max.fill", label: String(localized: "感情"), color: .yellow),
                    (icon: "leaf.fill", label: String(localized: "要因"), color: .green),
                    (icon: "mappin", label: String(localized: "場所"), color: .red),
                    (icon: "figure.walk", label: String(localized: "活動"), color: .blue),
                    (icon: "person.2.fill", label: String(localized: "人"), color: .purple),
                ])
            ),
            HelpItem(
                icon: "camera.fill",
                title: String(localized: "写真"),
                description: String(localized: "今の瞬間を写真で残せます。撮影またはライブラリから選択。iCloudに自動バックアップされます。"),
                diagram: nil
            ),
            HelpItem(
                icon: "mic.fill",
                title: String(localized: "ボイスメモ"),
                description: String(localized: "声で気持ちを残せます。長押しで録音、離して停止。再生して確認できます。"),
                diagram: .steps([
                    (number: 1, text: String(localized: "録音ボタンをタップ")),
                    (number: 2, text: String(localized: "話し終わったら停止")),
                    (number: 3, text: String(localized: "再生ボタンで確認")),
                ])
            ),
            HelpItem(
                icon: "battery.50percent",
                title: String(localized: "エネルギーレベル"),
                description: String(localized: "体力・エネルギーの状態を3段階で記録。気分スコアとは別の軸で、「気分は良いけど疲れている」パターンを発見できます。"),
                diagram: .iconRow([
                    (icon: "battery.25percent", label: String(localized: "低い"), color: .orange),
                    (icon: "battery.50percent", label: String(localized: "普通"), color: .blue),
                    (icon: "battery.100percent", label: String(localized: "高い"), color: .green),
                ])
            ),
        ]
    }

    // MARK: Main View Icon Help

    static var mainViewHelp: [HelpItem] {
        [
            HelpItem(
                icon: "flame.fill",
                title: String(localized: "ストリーク"),
                description: String(localized: "連続記録日数です。タップすると詳細（現在/最長/バッジ一覧）が見られます。マイルストーン達成で特別なアイコンに変わります。"),
                diagram: .iconRow([
                    (icon: "flame", label: "3" + String(localized: "日"), color: .orange),
                    (icon: "star.fill", label: "30" + String(localized: "日"), color: .blue),
                    (icon: "trophy.fill", label: "100" + String(localized: "日"), color: .purple),
                    (icon: "crown.fill", label: "365" + String(localized: "日"), color: .yellow),
                ])
            ),
            HelpItem(
                icon: "battery.50percent",
                title: String(localized: "エネルギーアイコン"),
                description: String(localized: "最新の記録のエネルギーレベルを表示しています。オレンジ＝低い、ブルー＝普通、グリーン＝高い。"),
                diagram: .iconRow([
                    (icon: "battery.25percent", label: String(localized: "低い"), color: .orange),
                    (icon: "battery.50percent", label: String(localized: "普通"), color: .blue),
                    (icon: "battery.100percent", label: String(localized: "高い"), color: .green),
                ])
            ),
            HelpItem(
                icon: "cloud.sun.fill",
                title: String(localized: "天気アイコン"),
                description: String(localized: "記録時の天気が自動で取得されています。設定でON/OFFできます。統計タブで天気×気分の相関が分析されます。"),
                diagram: .iconRow([
                    (icon: "sun.max.fill", label: String(localized: "晴れ"), color: .yellow),
                    (icon: "cloud.fill", label: String(localized: "曇り"), color: .gray),
                    (icon: "cloud.rain.fill", label: String(localized: "雨"), color: .blue),
                    (icon: "cloud.snow.fill", label: String(localized: "雪"), color: .cyan),
                ])
            ),
            HelpItem(
                icon: "square.grid.2x2",
                title: String(localized: "ウィジェット記録"),
                description: String(localized: "オレンジのグリッドアイコンはウィジェットから記録されたことを示します。タップしてメモやタグを追加できます。"),
                diagram: nil
            ),
        ]
    }

    // MARK: Settings Help Items

    static var settingsHelp: [HelpItem] {
        [
            HelpItem(
                icon: "square.grid.3x3",
                title: String(localized: "入力方式"),
                description: String(localized: "ボタングリッドはタップで素早く記録。スライダーは直感的にスコアを調整できます。お好みで切り替えてください。"),
                diagram: .comparison(
                    left: (icon: "square.grid.3x3", label: String(localized: "ボタン")),
                    right: (icon: "slider.horizontal.3", label: String(localized: "スライダー"))
                )
            ),
            HelpItem(
                icon: "heart.fill",
                title: String(localized: "HealthKitデータ"),
                description: String(localized: "各データを個別にON/OFFできます。OFFにしたデータは取得も分析もされません。Apple Watchがあるとより多くのデータが取得できます。"),
                diagram: .iconRow([
                    (icon: "figure.walk", label: String(localized: "歩数"), color: .green),
                    (icon: "bed.double.fill", label: String(localized: "睡眠"), color: .indigo),
                    (icon: "waveform.path.ecg", label: String(localized: "HRV"), color: .red),
                    (icon: "headphones", label: String(localized: "イヤホン"), color: .blue),
                ])
            ),
            HelpItem(
                icon: "square.and.arrow.up",
                title: String(localized: "CSVエクスポート"),
                description: String(localized: "全ての記録をCSVファイルとして書き出せます。Excelやスプレッドシートで開けます。"),
                diagram: nil
            ),
        ]
    }

    // MARK: PRO Feature Details

    static var proFeatureHelp: [HelpItem] {
        [
            HelpItem(
                icon: "arrow.triangle.branch",
                title: String(localized: "タグ遷移マップ"),
                description: String(localized: "タグの連鎖パターンを可視化。「不安→疲れ→運動→リラックス」のような流れが見えます。矢印の色はスコアの変化を示します。"),
                diagram: .comparison(
                    left: (icon: "cloud.rain.fill", label: String(localized: "不安")),
                    right: (icon: "sun.max.fill", label: String(localized: "リラックス"))
                )
            ),
            HelpItem(
                icon: "chart.line.uptrend.xyaxis",
                title: String(localized: "スコア予測"),
                description: String(localized: "曜日傾向・直近のトレンド・タグパターンから明日のスコアを予測。予測と実際のズレが大きい時は新しい気づきのチャンスです。"),
                diagram: .steps([
                    (number: 1, text: String(localized: "曜日の傾向を分析")),
                    (number: 2, text: String(localized: "直近3日のトレンドを計算")),
                    (number: 3, text: String(localized: "タグパターンを加味して予測")),
                ])
            ),
            HelpItem(
                icon: "waveform.path.ecg",
                title: String(localized: "タグ × HealthKit分析"),
                description: String(localized: "タグと健康データの掛け算。「仕事タグ × 睡眠6時間未満」のように、特定の状況で健康データがどう影響するかを自動分析します。"),
                diagram: .iconRow([
                    (icon: "tag.fill", label: String(localized: "タグ"), color: .blue),
                    (icon: "multiply", label: "×", color: .secondary),
                    (icon: "heart.fill", label: String(localized: "健康"), color: .red),
                    (icon: "equal", label: "=", color: .secondary),
                    (icon: "lightbulb.fill", label: String(localized: "発見"), color: .yellow),
                ])
            ),
            HelpItem(
                icon: "tag.fill",
                title: String(localized: "無制限カスタムタグ"),
                description: String(localized: "無料版は10個まで。PROでは無制限にオリジナルタグを作成できます。カテゴリも自由に追加可能。"),
                diagram: nil
            ),
        ]
    }

    // MARK: - Contextual Help (Stats Section Explanations)

    static var hrvExplanation: [HelpItem] {
        [
            HelpItem(
                icon: "waveform.path.ecg",
                title: String(localized: "HRV（心拍変動）とは？"),
                description: String(localized: "心拍のリズムの「ゆらぎ」を数値化したもの。自律神経のバランスを反映し、ストレスや疲労の客観的な指標になります。"),
                diagram: .scale(
                    labels: [String(localized: "緊張"), "", String(localized: "バランス"), "", String(localized: "リラックス")],
                    colors: [.red, .orange, .yellow, .green, .blue]
                )
            ),
            HelpItem(
                icon: "heart.text.clipboard",
                title: String(localized: "なぜ気分と関係があるの？"),
                description: String(localized: "HRVが高い日は自律神経のバランスが良く、感情のコントロールがしやすい状態。HRVが低い日はストレスや疲労が溜まっている可能性があり、気分が不安定になりやすい傾向があります。"),
                diagram: .comparison(
                    left: (icon: "arrow.up", label: String(localized: "HRV高い→好調")),
                    right: (icon: "arrow.down", label: String(localized: "HRV低い→不調"))
                )
            ),
            HelpItem(
                icon: "applewatch",
                title: String(localized: "計測方法"),
                description: String(localized: "Apple Watchを装着して寝ると、睡眠中のHRVが自動で計測されます。iPhoneのヘルスケアアプリでも確認可能です。"),
                diagram: nil
            ),
        ]
    }

    static var sleepCorrelation: [HelpItem] {
        [
            HelpItem(
                icon: "bed.double.fill",
                title: String(localized: "睡眠と気分の関係"),
                description: String(localized: "質の高い睡眠は翌日の感情の安定に直結します。睡眠時間だけでなく、入眠までの時間や中途覚醒の回数も気分に影響します。"),
                diagram: .steps([
                    (number: 1, text: String(localized: "良い睡眠 → 感情が安定")),
                    (number: 2, text: String(localized: "睡眠不足 → イライラ・不安が増加")),
                    (number: 3, text: String(localized: "一定の就寝時刻 → リズムが整う")),
                ])
            ),
            HelpItem(
                icon: "chart.bar.fill",
                title: String(localized: "Namiでの活用法"),
                description: String(localized: "ヘルスケアの睡眠データをONにすると、睡眠時間と気分スコアの相関を自動分析。「よく眠れた翌日のスコア平均」が分かります。Nemuriアプリと連携するとさらに詳しい分析が可能です。"),
                diagram: nil
            ),
        ]
    }

    static var stabilityExplanation: [HelpItem] {
        [
            HelpItem(
                icon: "waveform.path",
                title: String(localized: "安定度スコアとは？"),
                description: String(localized: "気分スコアの「振れ幅」を0〜100で数値化したもの。100に近いほど安定した日々を送れています。激しく上下している時期は数値が低くなります。"),
                diagram: .scale(
                    labels: [String(localized: "不安定"), "", String(localized: "普通"), "", String(localized: "安定")],
                    colors: [.red, .orange, .yellow, .mint, .green]
                )
            ),
            HelpItem(
                icon: "lightbulb.fill",
                title: String(localized: "自己理解への活かし方"),
                description: String(localized: "安定度が低い時期は、外的ストレスや生活リズムの乱れが原因かもしれません。タグと照らし合わせることで、波の原因が見えてきます。安定度の変化を追うことで、自分のメンタルの「波のパターン」が理解できるようになります。"),
                diagram: .comparison(
                    left: (icon: "water.waves", label: String(localized: "波が穏やか＝安定")),
                    right: (icon: "waveform", label: String(localized: "波が激しい＝変動"))
                )
            ),
        ]
    }
}
