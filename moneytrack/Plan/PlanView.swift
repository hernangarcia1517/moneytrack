//
//  PlanView.swift
//  moneytrack
//
//  Purpose: the one-glance answer to "how am I doing this month".
//

import SwiftUI

struct PlanView: View {
    @Environment(BudgetStore.self) private var store

    /// Set by ContentView after a transaction is saved (or by a group chip
    /// tap in BudgetDetailView) to auto-expand the group that changed.
    @Binding var groupToExpand: BudgetGroup?

    @State private var expanded: Set<BudgetGroup> = []
    @State private var newBudgetGroup: BudgetGroup?
    @State private var openBudgetID: Budget.ID?
    @State private var path: [Budget] = []

    private var month: DateInterval { store.currentMonth }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 0) {
                    MonthHeader()
                    headline

                    FadingRule()
                        .padding(.horizontal, Theme.Spacing.gutter)

                    VStack(spacing: 0) {
                        ForEach(BudgetGroup.allCases) { group in
                            GroupSection(
                                group: group,
                                isExpanded: expanded.contains(group),
                                openBudgetID: $openBudgetID,
                                onToggle: { toggle(group) },
                                onAddBudget: { newBudgetGroup = group },
                                onSelectBudget: { path.append($0) }
                            )
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.gutter)

                    footer
                }
            }
            .background(Theme.Color.background)
            .navigationDestination(for: Budget.self) { budget in
                BudgetDetailView(budget: budget, groupToExpand: $groupToExpand)
            }
        }
        .onChange(of: groupToExpand) { _, newValue in
            guard let group = newValue else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                _ = expanded.insert(group)
            }
            groupToExpand = nil
        }
        .sheet(item: $newBudgetGroup) { group in
            NewBudgetSheet(preselectedGroup: group)
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Money.string(store.totalSpent(in: month)))
                .font(.system(size: Theme.FontSize.s52, weight: .medium))
                .tracking(Theme.FontSize.s52 * -0.03)
                .foregroundStyle(Theme.Color.text)
                .monospacedDigit()
            Text("spent in \(monthName)")
                .font(.system(size: Theme.FontSize.s13))
                .foregroundStyle(Theme.Color.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.gutter)
        .padding(.top, Theme.Spacing.s14)
        .padding(.bottom, Theme.Spacing.s26)
    }

    private var footer: some View {
        HStack {
            Text("Budgeted this month")
            Spacer()
            Text(Money.string(store.totalPlanned(in: month)))
                .monospacedDigit()
        }
        .font(.system(size: Theme.FontSize.s13))
        .foregroundStyle(Theme.Color.textMuted)
        .padding(.horizontal, Theme.Spacing.gutter)
        .padding(.top, Theme.Spacing.s20)
        .padding(.bottom, Theme.Spacing.s20)
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.calendar = .gregorian
        formatter.dateFormat = "LLLL"
        return formatter.string(from: month.start)
    }

    private func toggle(_ group: BudgetGroup) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if expanded.contains(group) {
                expanded.remove(group)
            } else {
                expanded.insert(group)
            }
        }
    }
}
