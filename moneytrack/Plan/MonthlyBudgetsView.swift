//
//  MonthlyBudgetsView.swift
//  moneytrack
//
//  The full budget roster, pushed from Plan's "Budgeted this month" footer.
//  A drill-down like BudgetDetailView (keeps the tab bar visible), not a
//  modal. Tapping a row doesn't edit the cap inline here — it replaces this
//  screen with that budget's own BudgetDetailView (which already has the
//  month-scoped cap field), matching the design exactly. Swipe a row left
//  to delete it, same gesture as Plan/Spending (Phase 3).
//

import SwiftUI

struct MonthlyBudgetsView: View {
    @Environment(BudgetStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var groupToExpand: Binding<BudgetGroup?> = .constant(nil)
    var onSelectBudget: (Budget) -> Void = { _ in }

    @State private var openBudgetID: Budget.ID?
    @State private var isAddingBudget = false

    private var month: DateInterval { store.currentMonth }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    totalsSummary

                    ForEach(BudgetGroup.allCases) { group in
                        groupSection(group)
                    }

                    newBudgetButton
                        .padding(.top, Theme.Spacing.s4)

                    Text("Tap a budget to change its amount. Swipe a row left to delete it.")
                        .font(.system(size: Theme.FontSize.s12))
                        .foregroundStyle(Theme.Color.neutral500)
                        .padding(.top, Theme.Spacing.s14)
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.bottom, Theme.Spacing.s28)
            }
        }
        .background(Theme.Color.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isAddingBudget) {
            NewBudgetSheet(preselectedGroup: .bills) { budget in
                groupToExpand.wrappedValue = budget.group
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Monthly budgets")
                .font(.system(size: Theme.FontSize.s15, weight: .medium))
                .foregroundStyle(Theme.Color.text)

            Spacer()

            Button("Done") { dismiss() }
                .foregroundStyle(Theme.Color.accentText)
        }
        .font(.system(size: Theme.FontSize.s15))
        .padding(.horizontal, Theme.Spacing.gutter)
        .padding(.top, Theme.Spacing.s14)
        .padding(.bottom, Theme.Spacing.s10)
    }

    // MARK: - Totals

    private var totalsSummary: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Money.string(store.totalPlanned(in: month)))
                .font(.system(size: Theme.FontSize.s30, weight: .medium))
                .tracking(Theme.FontSize.s30 * -0.02)
                .foregroundStyle(Theme.Color.text)
                .monospacedDigit()
            Text("budgeted monthly")
                .font(.system(size: Theme.FontSize.s13))
                .foregroundStyle(Theme.Color.neutral400)
                .padding(.top, 9)
            Text(subtotalLine)
                .font(.system(size: Theme.FontSize.s12))
                .foregroundStyle(Theme.Color.neutral500)
                .padding(.top, Theme.Spacing.s6)
        }
        .padding(.top, Theme.Spacing.s6)
        .padding(.bottom, Theme.Spacing.s20)
    }

    /// "Bills $2,700  ·  Needs $800  ·  Wants $400" — whole-dollar
    /// subtotals drop the trailing ".00", matching the design.
    private var subtotalLine: String {
        BudgetGroup.allCases
            .map { group in
                let total = store.budgets(in: group).reduce(Decimal(0)) { $0 + store.budgetCap($1, in: month) }
                var amount = Money.string(total)
                if amount.hasSuffix(".00") { amount.removeLast(3) }
                return "\(group.rawValue) \(amount)"
            }
            .joined(separator: "  \u{00B7}  ")
    }

    // MARK: - Group sections

    private func groupSection(_ group: BudgetGroup) -> some View {
        let budgets = store.budgets(in: group)
        let subtotal = budgets.reduce(Decimal(0)) { $0 + store.budgetCap($1, in: month) }

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(group.rawValue.uppercased())
                Spacer()
                Text(Money.string(subtotal))
                    .monospacedDigit()
            }
            .font(.system(size: Theme.FontSize.s11))
            .tracking(0.5)
            .foregroundStyle(Theme.Color.neutral500)
            .padding(.top, Theme.Spacing.s10)
            .padding(.bottom, Theme.Spacing.s6)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.Color.neutral800).frame(height: 1)
            }

            ForEach(budgets) { budget in
                SwipeToDeleteRow(
                    id: budget.id,
                    openID: $openBudgetID,
                    onTap: { onSelectBudget(budget) },
                    onDelete: { store.deleteBudget(budget) }
                ) {
                    HStack {
                        Text(budget.name)
                            .font(.system(size: Theme.FontSize.s15))
                            .foregroundStyle(Theme.Color.neutral100)
                        Spacer()
                        HStack(spacing: 8) {
                            Text(Money.string(store.budgetCap(budget, in: month)))
                                .font(.system(size: Theme.FontSize.s15))
                                .foregroundStyle(Theme.Color.neutral300)
                                .monospacedDigit()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.Color.neutral500)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.s14)
                }
            }
        }
        .padding(.bottom, Theme.Spacing.s18)
    }

    // MARK: - New budget

    private var newBudgetButton: some View {
        Button {
            isAddingBudget = true
        } label: {
            Text("New budget")
                .font(.system(size: Theme.FontSize.s15))
                .foregroundStyle(Theme.Color.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.s14)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Color.accent, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
