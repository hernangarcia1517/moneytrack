//
//  DailyBars.swift
//  moneytrack
//
//  The scrubbable daily-spend bar chart at the top of Spending. Renders
//  every day of the month (not just elapsed ones — days after
//  `elapsedDayOfMonth` render as dim "future" stubs). A drag anywhere over
//  the chart reports which day is under the finger via `scrubbedDay`,
//  recoloring bars live; releasing resets it to nil.
//

import SwiftUI

struct DailyBars: View {
    /// One entry per day of the month, in order, day 1 first — already
    /// excludes Bills-group spend (that filtering happens in SpendingView).
    let dailyTotals: [Decimal]
    let elapsedDayOfMonth: Int
    let axisStartLabel: String
    let axisEndLabel: String
    @Binding var scrubbedDay: Int?

    private static let barsHeight: CGFloat = 96
    private static let maxBarHeight: CGFloat = 92
    private static let valueStubHeight: CGFloat = 3
    private static let emptyStubHeight: CGFloat = 2
    private static let barSpacing: CGFloat = 2

    @State private var measuredWidth: CGFloat = 0

    private var peak: Decimal {
        dailyTotals.max() ?? 0
    }

    var body: some View {
        VStack(spacing: 9) {
            HStack(alignment: .bottom, spacing: Self.barSpacing) {
                ForEach(Array(dailyTotals.enumerated()), id: \.offset) { index, total in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color(forDay: index + 1, total: total))
                        .frame(height: barHeight(for: total))
                        .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
            .frame(height: Self.barsHeight, alignment: .bottom)
            .animation(.easeInOut(duration: 0.12), value: scrubbedDay)

            HStack {
                Text(axisStartLabel)
                Spacer()
                Text(axisEndLabel)
            }
            .font(.system(size: Theme.FontSize.s10))
            .foregroundStyle(Theme.Color.neutral600)
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { measuredWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newValue in measuredWidth = newValue }
            }
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in scrub(at: value.location.x) }
                .onEnded { _ in scrubbedDay = nil }
        )
    }

    private func scrub(at x: CGFloat) {
        guard measuredWidth > 0, !dailyTotals.isEmpty else { return }
        let fraction = x / measuredWidth
        let day = Int((fraction * Double(dailyTotals.count)).rounded(.up))
        let clamped = max(1, min(dailyTotals.count, day))
        if scrubbedDay != clamped { scrubbedDay = clamped }
    }

    private func barHeight(for total: Decimal) -> CGFloat {
        guard total > 0, peak > 0 else { return Self.emptyStubHeight }
        let fraction = NSDecimalNumber(decimal: total / peak).doubleValue
        return max(CGFloat(fraction) * Self.maxBarHeight, Self.valueStubHeight)
    }

    private func color(forDay day: Int, total: Decimal) -> Color {
        let isFuture = day > elapsedDayOfMonth
        if scrubbedDay == day {
            return total > 0 ? Theme.Color.accent200 : Theme.Color.neutral600
        } else if isFuture {
            return Theme.Color.neutral800
        } else if total <= 0 {
            return Theme.Color.neutral700
        } else {
            return scrubbedDay != nil ? Theme.Color.accent700 : Theme.Color.accent
        }
    }
}
