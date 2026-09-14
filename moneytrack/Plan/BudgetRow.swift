//
//  BudgetRow.swift
//  moneytrack
//

import SwiftUI

struct BudgetRow: View {
    @Environment(BudgetStore.self) private var store
    let budget: Budget

    var body: some View {
        let month = store.currentMonth
        let budgetCap = store.budgetCap(budget, in: month)
        let spent = store.spent(budget, in: month)
        let isOver = spent > budgetCap

        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(budget.name)
                    .font(.system(size: Theme.FontSize.s15))
                    .foregroundStyle(Theme.Color.rowPrimary)
                Spacer()
                Text(Money.ofString(spent: spent, budgetCap: budgetCap))
                    .font(.system(size: Theme.FontSize.s13))
                    .foregroundStyle(isOver ? Theme.Color.negative : Theme.Color.textMuted)
                    .monospacedDigit()
            }

            ProgressTrack(fraction: fraction(spent: spent, budgetCap: budgetCap), isOver: isOver, height: 4)
        }
    }

    private func fraction(spent: Decimal, budgetCap: Decimal) -> Double {
        guard budgetCap > 0 else { return spent > 0 ? 1 : 0 }
        let value = NSDecimalNumber(decimal: spent / budgetCap).doubleValue
        return min(max(value, 0), 1)
    }
}

/// The clamped-at-100% progress bar used on Plan rows and BudgetDetailView.
/// Fill turns negative-red when over; corner radius is always half the
/// track's height, per the design system.
struct ProgressTrack: View {
    let fraction: Double
    let isOver: Bool
    var height: CGFloat = 4

    private var cornerRadius: CGFloat { height / 2 }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.Color.hairline)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isOver ? Theme.Color.negative : Theme.Color.accent)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: height)
        .animation(.easeInOut(duration: 0.3), value: fraction)
    }
}
