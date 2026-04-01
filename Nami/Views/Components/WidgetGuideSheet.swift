//
//  WidgetGuideSheet.swift
//  Nami
//
//  Widget guide with use-case-oriented recommendations
//

import SwiftUI

/// Full-screen widget guide organized by user intent
struct WidgetGuideSheet: View {
    let colors: ThemeColors
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(colors.accent)
                        Text(String(localized: "ウィジェットガイド"))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        Text(String(localized: "あなたの使い方に合ったウィジェットを見つけましょう"))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // Use case cards
                    useCaseCard(
                        emoji: "⚡",
                        title: String(localized: "とにかく素早く記録したい"),
                        recommendation: String(localized: "小サイズウィジェット"),
                        icon: "square.grid.2x2",
                        reason: String(localized: "ホーム画面からワンタップでスコアを記録できます。アプリを開く必要がありません。最新のスコアも常に表示されるので、前回の気分をすぐに振り返れます。"),
                        tip: String(localized: "よく使うホーム画面の親指が届く位置に配置するのがおすすめです。")
                    )

                    useCaseCard(
                        emoji: "📊",
                        title: String(localized: "1日の気分の変化を把握したい"),
                        recommendation: String(localized: "中サイズウィジェット"),
                        icon: "rectangle",
                        reason: String(localized: "直近のスコアトレンドがミニチャートで表示されます。記録ボタンも付いているので、グラフを見ながらその場で記録できます。「今日は下がり気味だな」という気づきが自然に生まれます。"),
                        tip: String(localized: "朝と夜に目に入る場所に置くと、1日2回の記録習慣がつきやすくなります。")
                    )

                    useCaseCard(
                        emoji: "🔍",
                        title: String(localized: "詳しい統計を一目で見たい"),
                        recommendation: String(localized: "大サイズウィジェット"),
                        icon: "rectangle.portrait",
                        reason: String(localized: "週間の平均スコア、ストリーク、チャートなどの統計情報がホーム画面に常に表示されます。アプリを開かずに自分の傾向を把握でき、記録ボタンからそのまま記録もできます。"),
                        tip: String(localized: "統計をよく見る方は、専用のホーム画面ページを作ってここに配置するのも良い方法です。")
                    )

                    Divider()
                        .padding(.horizontal)

                    // Lock screen section header
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(localized: "ロック画面ウィジェット"))
                            .font(.system(.headline, design: .rounded, weight: .bold))
                    }
                    .padding(.horizontal)

                    useCaseCard(
                        emoji: "👀",
                        title: String(localized: "iPhoneを見るたびに気分を意識したい"),
                        recommendation: String(localized: "円形（ロック画面）"),
                        icon: "circle",
                        reason: String(localized: "ロック画面にスコアゲージが常に表示されます。iPhoneを手に取るたびに「今の気分はどうだろう？」と自然に意識できるようになります。記録の習慣化に最も効果的なウィジェットです。"),
                        tip: String(localized: "時計の下のウィジェットエリアに追加できます。")
                    )

                    useCaseCard(
                        emoji: "🔥",
                        title: String(localized: "連続記録のモチベーションを保ちたい"),
                        recommendation: String(localized: "長方形（ロック画面）"),
                        icon: "rectangle.fill",
                        reason: String(localized: "現在のスコアとストリーク（連続記録日数）がロック画面に表示されます。「今日で7日連続！」という情報が目に入ることで、記録を途切れさせたくないという動機が生まれます。"),
                        tip: String(localized: "ストリークバッジと組み合わせて使うと効果的です。")
                    )

                    useCaseCard(
                        emoji: "📝",
                        title: String(localized: "最小限の情報だけ欲しい"),
                        recommendation: String(localized: "インライン（ロック画面）"),
                        icon: "textformat",
                        reason: String(localized: "時計の上の1行に、スコアとストリークがテキストで表示されます。一番さりげないウィジェットで、他人に見られても気にならないシンプルさです。"),
                        tip: String(localized: "プライバシーを気にする方にぴったりです。")
                    )

                    // How to add
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "追加方法"))
                            .font(.system(.headline, design: .rounded, weight: .bold))

                        stepRow(number: 1, text: String(localized: "ホーム画面を長押しして編集モードに"))
                        stepRow(number: 2, text: String(localized: "左上の「＋」ボタンをタップ"))
                        stepRow(number: 3, text: String(localized: "「Nami」で検索"))
                        stepRow(number: 4, text: String(localized: "好きなサイズを選んで「ウィジェットを追加」"))

                        Text(String(localized: "ロック画面ウィジェットは、ロック画面を長押し→「カスタマイズ」→「ロック画面」から追加できます。"))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(String(localized: "ウィジェットガイド"))
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

    // MARK: - Components

    private func useCaseCard(
        emoji: String,
        title: String,
        recommendation: String,
        icon: String,
        reason: String,
        tip: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Intent header
            HStack(spacing: 8) {
                Text(emoji)
                    .font(.title2)
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            }

            // Recommendation badge
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(recommendation)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
            }
            .foregroundStyle(colors.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(colors.accent.opacity(0.12)))

            // Reason
            Text(reason)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Tip
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
                Text(tip)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(colors.accent))
            Text(text)
                .font(.system(.subheadline, design: .rounded))
        }
    }
}
