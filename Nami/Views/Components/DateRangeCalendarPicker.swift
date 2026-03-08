//
//  DateRangeCalendarPicker.swift
//  Nami
//
//  Inline calendar picker with two tabs:
//  "日付選択" (calendar range select) and "柔軟な設定" (preset periods)
//

import SwiftUI

/// Inline date-range picker for graph filtering
struct DateRangeCalendarPicker: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @Binding var selectedPeriod: ChartPeriod?

    @Environment(\.themeManager) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    /// Active tab: 0 = calendar, 1 = presets
    @State private var activeTab = 0
    /// Displayed month (for calendar navigation)
    @State private var displayedMonth: Date = Date()

    private let calendar = Calendar.current

    var body: some View {
        let colors = themeManager.colors

        VStack(spacing: 12) {
            // Segmented tab
            Picker("", selection: $activeTab) {
                Text("日付選択").tag(0)
                Text("柔軟な設定").tag(1)
            }
            .pickerStyle(.segmented)

            if activeTab == 0 {
                calendarTab(colors: colors)
            } else {
                presetTab(colors: colors)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal)
    }

    // MARK: - Calendar Tab

    @ViewBuilder
    private func calendarTab(colors: ThemeColors) -> some View {
        VStack(spacing: 8) {
            // Month navigation
            monthHeader(colors: colors)

            // Weekday header
            weekdayHeader()

            // Day grid
            dayGrid(colors: colors)
        }
    }

    // MARK: - Month Navigation

    private func monthHeader(colors: ThemeColors) -> some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                }
                HapticManager.lightFeedback()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }

            Spacer()

            let year = calendar.component(.year, from: displayedMonth)
            let month = calendar.component(.month, from: displayedMonth)
            Text("\(String(year))年\(month)月")
                .font(.system(.title3, design: .rounded, weight: .bold))

            Spacer()

            // Disable forward navigation if current month is the latest
            let isCurrentMonth = calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                }
                HapticManager.lightFeedback()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(isCurrentMonth ? .clear : .secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .disabled(isCurrentMonth)
        }
    }

    // MARK: - Weekday Header

    private func weekdayHeader() -> some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        // Reorder starting from Sunday (Calendar default)
        return HStack(spacing: 0) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Day Grid

    @ViewBuilder
    private func dayGrid(colors: ThemeColors) -> some View {
        let weeks = weeksInMonth()

        VStack(spacing: 4) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { weekIndex, week in
                ZStack {
                    // Row highlight background for selected range
                    rowHighlight(week: week, weekIndex: weekIndex, totalWeeks: weeks.count)

                    // Day cells
                    HStack(spacing: 0) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            dayCell(day: day, colors: colors)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Row Highlight

    @ViewBuilder
    private func rowHighlight(week: [DayItem], weekIndex: Int, totalWeeks: Int) -> some View {
        guard let start = startDate, let end = endDate else {
            EmptyView()
            return
        }

        let rangeStart = min(start, end)
        let rangeEnd = max(start, end)

        // Find the first and last real (non-placeholder) day in this row that fall in the range
        let daysInRange = week.compactMap { item -> Date? in
            guard let date = item.date, !item.isPlaceholder else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let rangeStartDay = calendar.startOfDay(for: rangeStart)
            let rangeEndDay = calendar.startOfDay(for: rangeEnd)
            return (dayStart >= rangeStartDay && dayStart <= rangeEndDay) ? date : nil
        }

        if !daysInRange.isEmpty {
            GeometryReader { geo in
                let cellWidth = geo.size.width / 7
                let cellHeight = geo.size.height

                // Find the leftmost and rightmost column indices in range
                let indicesInRange = week.enumerated().compactMap { idx, item -> Int? in
                    guard let date = item.date, !item.isPlaceholder else { return nil }
                    let dayStart = calendar.startOfDay(for: date)
                    let rangeStartDay = calendar.startOfDay(for: rangeStart)
                    let rangeEndDay = calendar.startOfDay(for: rangeEnd)
                    return (dayStart >= rangeStartDay && dayStart <= rangeEndDay) ? idx : nil
                }

                if let firstIdx = indicesInRange.first, let lastIdx = indicesInRange.last {
                    let x = CGFloat(firstIdx) * cellWidth
                    let width = CGFloat(lastIdx - firstIdx + 1) * cellWidth
                    let cornerRadius: CGFloat = 20

                    // Determine which corners to round
                    let isRangeStartInRow = week.contains { item in
                        guard let date = item.date else { return false }
                        return calendar.isDate(date, inSameDayAs: rangeStart)
                    }
                    let isRangeEndInRow = week.contains { item in
                        guard let date = item.date else { return false }
                        return calendar.isDate(date, inSameDayAs: rangeEnd)
                    }

                    let corners: UIRectCorner = {
                        if isRangeStartInRow && isRangeEndInRow {
                            return .allCorners
                        } else if isRangeStartInRow {
                            return [.topLeft, .bottomLeft]
                        } else if isRangeEndInRow {
                            return [.topRight, .bottomRight]
                        } else {
                            return []
                        }
                    }()

                    RoundedCornersShape(radius: cornerRadius, corners: corners)
                        .fill(Color(.systemGray5).opacity(0.8))
                        .frame(width: width, height: cellHeight)
                        .offset(x: x)
                }
            }
        } else {
            EmptyView()
        }
    }

    // MARK: - Day Cell

    private func dayCell(day: DayItem, colors: ThemeColors) -> some View {
        let isSelected = isDateSelected(day.date)
        let isFuture = day.date.map { calendar.compare($0, to: Date(), toGranularity: .day) == .orderedDescending } ?? false

        Button {
            guard let date = day.date, !day.isPlaceholder, !isFuture else { return }
            handleDateTap(date)
            HapticManager.lightFeedback()
        } label: {
            Text(day.text)
                .font(.system(.body, design: .rounded, weight: isSelected ? .bold : .regular))
                .foregroundStyle(
                    day.isPlaceholder ? .clear
                        : isFuture ? Color(.systemGray3)
                        : isSelected ? .white
                        : .primary
                )
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background {
                    if isSelected {
                        Circle()
                            .fill(Color.primary)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(day.isPlaceholder || isFuture)
    }

    // MARK: - Selection Logic

    private func isDateSelected(_ date: Date?) -> Bool {
        guard let date else { return false }
        if let s = startDate, calendar.isDate(date, inSameDayAs: s) { return true }
        if let e = endDate, calendar.isDate(date, inSameDayAs: e) { return true }
        return false
    }

    private func handleDateTap(_ date: Date) {
        if startDate == nil {
            // First tap: set start
            startDate = date
            endDate = nil
            selectedPeriod = nil
        } else if endDate == nil {
            // Second tap: set end (swap if needed)
            if let s = startDate, calendar.isDate(date, inSameDayAs: s) {
                // Same day tapped → single day selection
                endDate = date
            } else if let s = startDate, date < s {
                endDate = startDate
                startDate = date
            } else {
                endDate = date
            }
            selectedPeriod = nil
        } else {
            // Third tap: restart
            startDate = date
            endDate = nil
            selectedPeriod = nil
        }
    }

    // MARK: - Preset Tab

    @ViewBuilder
    private func presetTab(colors: ThemeColors) -> some View {
        let presets = ChartPeriod.allCases

        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 10) {
            ForEach(presets) { period in
                let isActive = selectedPeriod == period
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPeriod = period
                        startDate = nil
                        endDate = nil
                    }
                    HapticManager.lightFeedback()
                } label: {
                    Text(LocalizedStringKey(period.rawValue))
                        .font(.system(.subheadline, design: .rounded, weight: isActive ? .bold : .medium))
                        .foregroundStyle(isActive ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isActive ? colors.accent : Color(.systemGray5).opacity(0.6))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Calendar Data

    private struct DayItem {
        let text: String
        let date: Date?
        let isPlaceholder: Bool
    }

    /// Generate weeks (arrays of 7 DayItems) for the displayed month
    private func weeksInMonth() -> [[DayItem]] {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstOfMonth = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth)
        else { return [] }

        // Weekday of 1st (1=Sunday ... 7=Saturday)
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlanks = firstWeekday - calendar.firstWeekday
        let adjustedLeading = leadingBlanks >= 0 ? leadingBlanks : leadingBlanks + 7

        var items: [DayItem] = []

        // Leading placeholders
        for _ in 0 ..< adjustedLeading {
            items.append(DayItem(text: "", date: nil, isPlaceholder: true))
        }

        // Actual days
        for day in range {
            if let date = calendar.date(bySetting: .day, value: day, of: firstOfMonth) {
                items.append(DayItem(text: "\(day)", date: date, isPlaceholder: false))
            }
        }

        // Trailing placeholders to fill last week
        while items.count % 7 != 0 {
            items.append(DayItem(text: "", date: nil, isPlaceholder: true))
        }

        // Split into weeks
        return stride(from: 0, to: items.count, by: 7).map { start in
            Array(items[start ..< min(start + 7, items.count)])
        }
    }
}

// MARK: - Rounded Corners Shape

/// Shape that rounds specific corners
private struct RoundedCornersShape: Shape {
    var radius: CGFloat = 12
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var start: Date? = nil
        @State var end: Date? = nil
        @State var period: ChartPeriod? = .week

        var body: some View {
            VStack {
                DateRangeCalendarPicker(
                    startDate: $start,
                    endDate: $end,
                    selectedPeriod: $period
                )

                Text("Start: \(start?.description ?? "nil")")
                Text("End: \(end?.description ?? "nil")")
                Text("Period: \(period?.rawValue ?? "custom")")
            }
            .environment(\.themeManager, ThemeManager())
        }
    }
    return PreviewWrapper()
}
