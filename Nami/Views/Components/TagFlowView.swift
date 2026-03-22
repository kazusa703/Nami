import SwiftUI

/// Tag transition flow visualization (Premium feature)
/// Shows which tags tend to follow other tags, with directional curved arrows
struct TagFlowView: View {
    let transitions: [TagChain]
    let colors: ThemeColors

    @State private var selectedTag: String?

    var body: some View {
        if transitions.isEmpty {
            emptyState
        } else {
            VStack(spacing: 16) {
                flowDiagram
                if let selected = selectedTag {
                    detailCard(for: selected)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: selectedTag)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(String(localized: "タグを記録すると遷移パターンが表示されます"))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Flow Diagram

    private var flowDiagram: some View {
        GeometryReader { geo in
            let size = geo.size
            let tags = uniqueTags
            let total = tags.count

            ZStack {
                // Draw edges first (behind nodes)
                ForEach(filteredTransitions, id: \.id) { t in
                    if let fromIdx = tags.firstIndex(of: t.fromTag),
                       let toIdx = tags.firstIndex(of: t.toTag) {
                        let from = nodePosition(index: fromIdx, total: total, in: size)
                        let to = nodePosition(index: toIdx, total: total, in: size)
                        arrowView(
                            from: from,
                            to: to,
                            color: edgeColor(for: t.avgScoreChange),
                            thickness: edgeThickness(for: t.occurrences),
                            dimmed: selectedTag != nil && selectedTag != t.fromTag && selectedTag != t.toTag
                        )
                    }
                }

                // Draw nodes on top
                ForEach(Array(tags.enumerated()), id: \.element) { index, tag in
                    let pos = nodePosition(index: index, total: total, in: size)
                    let isSelected = selectedTag == tag
                    let isDimmed = selectedTag != nil && !isSelected && !isConnected(tag)

                    nodeView(tag: tag, isSelected: isSelected)
                        .opacity(isDimmed ? 0.35 : 1.0)
                        .position(pos)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedTag = selectedTag == tag ? nil : tag
                            }
                        }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Detail Card

    @ViewBuilder
    private func detailCard(for tag: String) -> some View {
        let outgoing = filteredTransitions.filter { $0.fromTag == tag }
        let incoming = filteredTransitions.filter { $0.toTag == tag }

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tag)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Spacer()
                Button {
                    withAnimation { selectedTag = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            if !outgoing.isEmpty {
                Text(String(localized: "次に多いタグ"))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                ForEach(outgoing, id: \.id) { t in
                    detailRow(label: t.toTag, count: t.occurrences, change: t.avgScoreChange)
                }
            }

            if !incoming.isEmpty {
                Text(String(localized: "前に多いタグ"))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                ForEach(incoming, id: \.id) { t in
                    detailRow(label: t.fromTag, count: t.occurrences, change: t.avgScoreChange)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }

    private func detailRow(label: String, count: Int, change: Double) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(.caption, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(colors.accent.opacity(0.1)))
            Spacer()
            Text(String(localized: "\(count)回"))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 8))
                Text(String(format: "%+.1f", change))
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
            }
            .foregroundStyle(edgeColor(for: change))
        }
    }

    // MARK: - Node View

    private func nodeView(tag: String, isSelected: Bool) -> some View {
        let score = averageScoreChange(for: tag)
        return VStack(spacing: 2) {
            Text(tag)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let s = score {
                Text(String(format: "%+.1f", s))
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(edgeColor(for: s))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minWidth: 52, minHeight: 36)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? colors.accent.opacity(0.2) : .primary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? colors.accent : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
    }

    // MARK: - Arrow Drawing

    private func arrowView(from: CGPoint, to: CGPoint, color: Color, thickness: CGFloat, dimmed: Bool) -> some View {
        let nodeRadius: CGFloat = 28
        let dx = to.x - from.x
        let dy = to.y - from.y
        let dist = hypot(dx, dy)
        guard dist > 0 else { return AnyView(EmptyView()) }

        // Shorten endpoints to stop at node edges
        let ux = dx / dist
        let uy = dy / dist
        let startPt = CGPoint(x: from.x + ux * nodeRadius, y: from.y + uy * nodeRadius)
        let endPt = CGPoint(x: to.x - ux * nodeRadius, y: to.y - uy * nodeRadius)

        // Quadratic bezier control point offset perpendicular to the line
        let midX = (startPt.x + endPt.x) / 2
        let midY = (startPt.y + endPt.y) / 2
        let perpX = -uy
        let perpY = ux
        let curveOffset: CGFloat = dist * 0.15
        let control = CGPoint(x: midX + perpX * curveOffset, y: midY + perpY * curveOffset)

        // Arrowhead points
        let arrowLen: CGFloat = 8
        let arrowAngle: CGFloat = CGFloat.pi / 6
        // Tangent at endpoint of quadratic bezier: derivative at t=1 = 2*(P2-C)
        let tangentX = endPt.x - control.x
        let tangentY = endPt.y - control.y
        let tangentDist = hypot(tangentX, tangentY)
        let tx = tangentX / max(tangentDist, 0.001)
        let ty = tangentY / max(tangentDist, 0.001)
        let leftX = endPt.x - arrowLen * (tx * cos(arrowAngle) - ty * sin(arrowAngle))
        let leftY = endPt.y - arrowLen * (ty * cos(arrowAngle) + tx * sin(arrowAngle))
        let rightX = endPt.x - arrowLen * (tx * cos(arrowAngle) + ty * sin(arrowAngle))
        let rightY = endPt.y - arrowLen * (ty * cos(arrowAngle) - tx * sin(arrowAngle))

        let view = Path { path in
            // Curved line
            path.move(to: startPt)
            path.addQuadCurve(to: endPt, control: control)
        }
        .stroke(color.opacity(dimmed ? 0.15 : 0.7), lineWidth: thickness)
        .overlay(
            Path { path in
                // Arrowhead
                path.move(to: endPt)
                path.addLine(to: CGPoint(x: leftX, y: leftY))
                path.move(to: endPt)
                path.addLine(to: CGPoint(x: rightX, y: rightY))
            }
            .stroke(color.opacity(dimmed ? 0.15 : 0.8), lineWidth: max(thickness, 1.5))
        )

        return AnyView(view)
    }

    // MARK: - Layout Helpers

    /// Top 8 most frequent tags from transitions
    private var uniqueTags: [String] {
        var freq: [String: Int] = [:]
        for t in transitions {
            freq[t.fromTag, default: 0] += t.occurrences
            freq[t.toTag, default: 0] += t.occurrences
        }
        return freq.sorted { $0.value > $1.value }
            .prefix(8)
            .map(\.key)
    }

    /// Transitions filtered to only include uniqueTags
    private var filteredTransitions: [IdentifiableTagChain] {
        let tags = Set(uniqueTags)
        return transitions
            .filter { tags.contains($0.fromTag) && tags.contains($0.toTag) }
            .map { IdentifiableTagChain(chain: $0) }
    }

    /// Position nodes in a circle
    private func nodePosition(index: Int, total: Int, in size: CGSize) -> CGPoint {
        guard total > 0 else { return CGPoint(x: size.width / 2, y: size.height / 2) }
        let radius = min(size.width, size.height) * 0.35
        let angle: CGFloat = (2.0 * CGFloat.pi / CGFloat(total)) * CGFloat(index) - CGFloat.pi / 2.0
        return CGPoint(
            x: size.width / 2 + radius * cos(angle),
            y: size.height / 2 + radius * sin(angle)
        )
    }

    /// Color based on score change direction
    private func edgeColor(for change: Double) -> Color {
        if change > 0.05 { return .green }
        if change < -0.05 { return .orange }
        return .gray
    }

    /// Line thickness scaled by occurrence count (1-4pt)
    private func edgeThickness(for count: Int) -> CGFloat {
        let counts = transitions.map { $0.occurrences }
        let maxCount = counts.max() ?? 1
        let minCount = counts.min() ?? 1
        guard maxCount > minCount else { return 2.0 }
        let ratio = CGFloat(count - minCount) / CGFloat(maxCount - minCount)
        return 1.0 + ratio * 3.0
    }

    /// Average outgoing score change for a tag
    private func averageScoreChange(for tag: String) -> Double? {
        let relevant = transitions.filter { $0.fromTag == tag || $0.toTag == tag }
        guard !relevant.isEmpty else { return nil }
        let total = relevant.reduce(0.0) { $0 + $1.avgScoreChange }
        return total / Double(relevant.count)
    }

    /// Whether a tag is connected to the selected tag
    private func isConnected(_ tag: String) -> Bool {
        guard let selected = selectedTag else { return false }
        return transitions.contains { t in
            (t.fromTag == selected && t.toTag == tag) ||
            (t.toTag == selected && t.fromTag == tag)
        }
    }
}

// MARK: - Identifiable Wrapper

private struct IdentifiableTagChain: Identifiable {
    let chain: TagChain
    var id: String { "\(chain.fromTag)|\(chain.toTag)" }

    var fromTag: String { chain.fromTag }
    var toTag: String { chain.toTag }
    var occurrences: Int { chain.occurrences }
    var avgScoreChange: Double { chain.avgScoreChange }
}
