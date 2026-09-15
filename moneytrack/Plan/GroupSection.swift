//
//  GroupSection.swift
//  moneytrack
//
//  A single Bills/Needs/Wants row on Plan: the group header, and — when
//  expanded — its budget rows plus the "Add a budget" footer.
//

import SwiftUI

struct GroupSection: View {
    @Environment(BudgetStore.self) private var store

    let group: BudgetGroup
    let isExpanded: Bool
    @Binding var openBudgetID: Budget.ID?
    var onToggle: () -> Void
    var onAddBudget: () -> Void
    var onSelectBudget: (Budget) -> Void

    private var month: DateInterval { store.currentMonth }

    var body: some View {
        VStack(spacing: 0) {
            header

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(store.budgets(in: group)) { budget in
                        SwipeToDeleteRow(
                            id: budget.id,
                            openID: $openBudgetID,
                            cornerRadius: Theme.Radius.row,
                            onTap: { onSelectBudget(budget) },
                            onDelete: { store.deleteBudget(budget) }
                        ) {
                            BudgetRow(budget: budget)
                                .padding(.vertical, 11)
                                .padding(.horizontal, 12)
                        }
                    }
                    addBudgetFooter
                }
                .padding(.leading, 19)
                .padding(.bottom, Theme.Spacing.s8)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.Color.hairline).frame(height: 1)
        }
    }

    private var header: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Color.textMuted)
                    .frame(width: 9, height: 13)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.18), value: isExpanded)

                Text(group.rawValue)
                    .font(.system(size: Theme.FontSize.s17, weight: .medium))
                    .foregroundStyle(Theme.Color.text)

                Spacer()

                let remaining = store.remaining(group, in: month)
                Text(Money.remainingString(remaining))
                    .font(.system(size: Theme.FontSize.s15))
                    .foregroundStyle(remaining < 0 ? Theme.Color.negative : Theme.Color.textSecondary)
                    .monospacedDigit()
            }
            .padding(.vertical, 18)
        }
        .buttonStyle(.plain)
    }

    private var addBudgetFooter: some View {
        Button(action: onAddBudget) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 13, height: 13)
                Text("Add a budget to \(group.rawValue)")
                    .font(.system(size: 14))
            }
            .foregroundStyle(Theme.Color.accentText)
            .padding(.vertical, 11)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
