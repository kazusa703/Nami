//
//  FAQView.swift
//  Nami
//
//  Native FAQ (accordion) — replaces external support link
//

import SwiftUI

// MARK: - Data Model

struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

// MARK: - FAQ Content

enum FAQContent {
    static let items: [FAQItem] = [
        FAQItem(
            question: String(localized: "記録を編集・削除するには？"),
            answer: String(localized: "グラフタブで日をタップすると、その日の記録一覧が表示されます。各記録の右にある「>」をタップして詳細を開き、メモの編集や削除が可能です。統計タブの「アクティビティ」セクションからも最近の記録を編集できます。")
        ),
        FAQItem(
            question: String(localized: "スコアの範囲（レンジ）を変更したらどうなる？"),
            answer: String(localized: "過去のデータは安全に保持されます。レンジを変更すると、過去のスコアは自動的に新しい範囲にスケーリング（換算）されてグラフや統計に表示されるため、比較にズレが生じることはありません。いつでも安心してレンジを変更できます。")
        ),
        FAQItem(
            question: String(localized: "ウィジェットや通知で記録したスコアにタグを追加するには？"),
            answer: String(localized: "アプリを開くと、記録タブの上部に「N件の記録にタグ・メモを追加できます」というバナーが表示されます。タップすると、タグやメモを後から補完できます。グラフタブのタイムラインでも「＋ タグやメモを追加…」ボタンから追加可能です。")
        ),
        FAQItem(
            question: String(localized: "データはiCloudで同期されますか？"),
            answer: String(localized: "はい。iCloudがオンの場合、SwiftDataの自動同期により、同じApple IDでログインしているすべてのiPhoneで記録が共有されます。写真やボイスメモはデバイスにのみ保存され、同期対象外です。")
        ),
        FAQItem(
            question: String(localized: "カスタムタグの作り方は？"),
            answer: String(localized: "設定タブ → 「タグを管理」 → 右上の「＋」ボタンから追加できます。記録シートのタグ選択画面の一番下にある「＋ 新しいタグを作成」ボタンからも、その場で作成可能です。無料版は10個まで、プレミアムは無制限です。")
        ),
        FAQItem(
            question: String(localized: "Nemuriアプリとの連携方法は？"),
            answer: String(localized: "Nemuri（睡眠トラッキングアプリ）がインストールされていれば、自動的にApp Group経由でデータが共有されます。特別な設定は不要です。統計タブに睡眠×気分の相関インサイトが表示されるようになります。")
        ),
        FAQItem(
            question: String(localized: "インサイトが表示されません"),
            answer: String(localized: "インサイトの生成には最低20件の記録が必要です。統計タブの上部にプログレスバーが表示され、あと何件で解放されるか確認できます。毎日記録を続けると、約3週間で最初のAIインサイトが表示されます。")
        ),
        FAQItem(
            question: String(localized: "データのエクスポート（書き出し）方法は？"),
            answer: String(localized: "設定タブ → 「データのエクスポート」からCSVファイルとして全記録を書き出せます。日時、スコア、メモ、タグ、天気などが含まれます。他のアプリやスプレッドシートで分析する場合に便利です。")
        ),
        // Purchase restore FAQ moved to ProView's dedicated PRO FAQ section
    ]
}

// MARK: - FAQ View

struct FAQView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeManager) private var themeManager
    @State private var expandedID: UUID?

    var body: some View {
        let colors = themeManager.colors

        ScrollView {
            VStack(spacing: 0) {
                ForEach(FAQContent.items) { item in
                    faqRow(item: item, colors: colors)

                    if item.id != FAQContent.items.last?.id {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .background(colors.backgroundGradient(for: colorScheme).ignoresSafeArea())
        .navigationTitle(String(localized: "よくある質問"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func faqRow(item: FAQItem, colors: ThemeColors) -> some View {
        let isExpanded = expandedID == item.id

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                expandedID = isExpanded ? nil : item.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(colors.accent.opacity(0.7))
                        .padding(.top, 2)

                    Text(item.question)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .padding(.vertical, 14)

                if isExpanded {
                    Text(item.answer)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 28)
                        .padding(.bottom, 14)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        FAQView()
    }
    .environment(\.themeManager, ThemeManager())
}
