//
//  TooltipView.swift
//  Nami
//
//  Reusable tooltip with frosted-glass background and directional arrow.
//

import SwiftUI

/// A floating tooltip bubble with a triangular tail.
struct TooltipView: View {
    let text: String
    let accentColor: Color
    var tailEdge: Edge = .bottom

    var body: some View {
        VStack(spacing: 0) {
            if tailEdge == .top {
                tail
                    .rotationEffect(.degrees(180))
            }

            Text(text)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(accentColor.opacity(0.3), lineWidth: 1)
                        )
                )

            if tailEdge == .bottom {
                tail
            }
        }
    }

    private var tail: some View {
        TooltipTail()
            .fill(.ultraThickMaterial)
            .overlay(
                TooltipTail()
                    .stroke(accentColor.opacity(0.3), lineWidth: 1)
            )
            .frame(width: 16, height: 8)
    }
}

/// Triangle shape for tooltip tail
private struct TooltipTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 40) {
        TooltipView(
            text: "あとで自分だけのタグも自由に作れます",
            accentColor: .blue,
            tailEdge: .bottom
        )
        TooltipView(
            text: "ここをタップしてみましょう",
            accentColor: .orange,
            tailEdge: .top
        )
    }
    .padding()
}
