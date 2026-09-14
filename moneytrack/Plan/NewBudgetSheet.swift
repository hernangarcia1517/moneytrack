//
//  NewBudgetSheet.swift
//  moneytrack
//
//  A bottom sheet for creating a budget. Reachable from a Plan group's
//  "Add a budget to X" footer and from step 3 of AddTransactionView.
//

import SwiftUI

struct NewBudgetSheet: View {
    @Environment(BudgetStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let preselectedGroup: BudgetGroup
    /// Called after the budget is created and the sheet has begun dismissing
    /// — lets a caller (e.g. AddTransactionView) select it and advance.
    var onCreate: (Budget) -> Void = { _ in }

    @State private var name = ""
    @State private var group: BudgetGroup
    @State private var capText = ""

    init(preselectedGroup: BudgetGroup, onCreate: @escaping (Budget) -> Void = { _ in }) {
        self.preselectedGroup = preselectedGroup
        self.onCreate = onCreate
        _group = State(initialValue: preselectedGroup)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var canAdd: Bool { !trimmedName.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: Theme.Spacing.s20) {
                field(label: "Name", placeholder: "Phone plan", text: $name)

                VStack(alignment: .leading, spacing: 8) {
                    Text("GROUP")
                        .font(.system(size: Theme.FontSize.s11))
                        .tracking(0.5)
                        .foregroundStyle(Theme.Color.textFaint)
                    HStack(spacing: 8) {
                        ForEach(BudgetGroup.allCases) { candidate in
                            GroupChip(title: candidate.rawValue, isSelected: group == candidate, fillsWidth: true) {
                                group = candidate
                            }
                        }
                    }
                }

                field(label: "Monthly budget", placeholder: "45", text: $capText, keyboard: .decimalPad)

                Text("Applies from \(monthName) onward. You can change or delete it any time from the budget's page.")
                    .font(.system(size: Theme.FontSize.s12))
                    .foregroundStyle(Theme.Color.textFaint)
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.top, Theme.Spacing.s20)
            .padding(.bottom, Theme.Spacing.s28)
        }
        .background(
            Theme.Color.surface
                .clipShape(.rect(topLeadingRadius: Theme.Radius.sheetTop, topTrailingRadius: Theme.Radius.sheetTop))
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.Color.border).frame(height: 1)
                }
                .ignoresSafeArea()
        )
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private var header: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .foregroundStyle(Theme.Color.textMuted)

            Spacer()

            Text("New budget")
                .font(.system(size: Theme.FontSize.s15, weight: .medium))
                .foregroundStyle(Theme.Color.text)

            Spacer()

            Button("Add", action: add)
                .foregroundStyle(canAdd ? Theme.Color.accent : Theme.Color.disabledInk)
        }
        .font(.system(size: Theme.FontSize.s15))
        .padding(.horizontal, Theme.Spacing.gutter)
        .padding(.vertical, Theme.Spacing.s14)
    }

    private func field(label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: Theme.FontSize.s13))
                .foregroundStyle(Theme.Color.textMuted)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(.system(size: Theme.FontSize.s15))
                .foregroundStyle(Theme.Color.text)
                .padding(.vertical, Theme.Spacing.s12)
                .padding(.horizontal, Theme.Spacing.s14)
                .background(Theme.Color.hoverFill)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.calendar = .gregorian
        formatter.dateFormat = "LLLL"
        return formatter.string(from: store.currentMonth.start)
    }

    private func add() {
        guard canAdd, !store.isNameTaken(trimmedName) else { return }
        let cap = Decimal(string: capText) ?? 0
        let budget = store.addBudget(name: trimmedName, group: group, cap: cap)
        dismiss()
        onCreate(budget)
    }
}
