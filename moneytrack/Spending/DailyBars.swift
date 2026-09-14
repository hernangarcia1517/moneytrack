//
//  DailyBars.swift
//  moneytrack
//
//  The elapsed-days-of-the-month bar chart at the top of Spending.
//

import SwiftUI

struct DailyBars: View {
    /// One entry per elapsed day of the month, in order, day 1 first.
    let dailyTotals: [Decimal]

    private static let chartHeight: CGFloat = 104
    private static let maxBarHeight: CGFloat = 88
    private static let stubHeight: CGFloat = 1
    private static let labeledDays: Set<Int> = [1, 5, 10, 15, 20, 25, 30]

    private var peak: Decimal {
        dailyTotals.max() ?? 0
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(dailyTotals.enumerated()), id: \.offset) { index, total in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(total > 0 ? Theme.Color.accent : Theme.Color.hairline)
                        .frame(height: barHeight(for: total))
                        .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
            .frame(height: Self.chartHeight, alignment: .bottom)

            HStack(spacing: 4) {
                ForEach(Array(dailyTotals.indices), id: \.self) { index in
                    let day = index + 1
                    Text(Self.labeledDays.contains(day) ? "\(day)" : "")
                        .font(.system(size: Theme.FontSize.s8))
                        .foregroundStyle(Theme.Color.textFaint)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func barHeight(for total: Decimal) -> CGFloat {
        guard total > 0, peak > 0 else { return Self.stubHeight }
        let fraction = NSDecimalNumber(decimal: total / peak).doubleValue
        return max(CGFloat(fraction) * Self.maxBarHeight, Self.stubHeight)
    }
}
