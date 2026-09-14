//
//  AddTransactionView.swift
//  moneytrack
//
//  Presented full-screen (not a sheet — an explicit design change) from the
//  centre "+" button. Nothing is written to the store until Save on step 4.
//

import SwiftUI

struct AddTransactionView: View {
    @Environment(BudgetStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Called after the transaction is saved, with the budget it landed in,
    /// so the caller can auto-expand that group on Plan.
    var onSaved: (Budget.ID) -> Void

    @State private var step = 0
    @State private var amountString = ""
    @State private var merchant = ""
    @State private var selectedBudgetID: Budget.ID?
    @State private var note = ""
    @State private var isAddingBudget = false

    private static let titles = ["Amount", "Where", "Budget", "Review"]

    private var amount: Decimal { Decimal(string: amountString) ?? 0 }
    private var selectedBudget: Budget? { store.budget(for: selectedBudgetID) }

    private var isStepSatisfied: Bool {
        switch step {
        case 0: return amount > 0
        case 2: return selectedBudgetID != nil
        default: return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
            Spacer(minLength: 0)
            actionBar
        }
        .background(Theme.Color.background.ignoresSafeArea())
        .sheet(isPresented: $isAddingBudget) {
            NewBudgetSheet(preselectedGroup: .bills) { budget in
                selectedBudgetID = budget.id
                step = 3
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .foregroundStyle(Theme.Color.textMuted)

            Spacer()

            Text(Self.titles[step])
                .font(.system(size: Theme.FontSize.s15, weight: .medium))
                .foregroundStyle(Theme.Color.text)

            Spacer()

            HStack(spacing: 5) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(dotColor(for: i))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .font(.system(size: Theme.FontSize.s15))
        .padding(.horizontal, Theme.Spacing.gutter)
        .padding(.top, Theme.Spacing.s14)
        .padding(.bottom, Theme.Spacing.s10)
    }

    private func dotColor(for index: Int) -> Color {
        if index == step { return Theme.Color.accent }
        if index < step { return Theme.Color.accentDeep }
        return Theme.Color.hairline
    }

    // MARK: - Step content

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: amountStep
        case 1: whereStep
        case 2: budgetStep
        default: reviewStep
        }
    }

    // Step 1 — Amount
    private var amountStep: some View {
        VStack(spacing: 0) {
            Text(amountDisplay)
                .font(.system(size: Theme.FontSize.s48, weight: .medium))
                .foregroundStyle(amountString.isEmpty ? Theme.Color.disabledInk : Theme.Color.text)
                .monospacedDigit()
                .padding(.top, 56)
                .padding(.bottom, 40)

            AmountKeypad(onDigit: appendDigit, onDecimal: appendDecimal, onBackspace: backspace)
                .padding(.horizontal, Theme.Spacing.gutter)
        }
    }

    private var amountDisplay: String {
        amountString.isEmpty ? "$0" : "$\(amountString)"
    }

    private func appendDigit(_ d: String) {
        if amountString == "0" {
            amountString = d
        } else if let dotIndex = amountString.firstIndex(of: ".") {
            let decimals = amountString.distance(from: amountString.index(after: dotIndex), to: amountString.endIndex)
            if decimals < 2 { amountString += d }
        } else {
            amountString += d
        }
    }

    private func appendDecimal() {
        if amountString.isEmpty {
            amountString = "0."
        } else if !amountString.contains(".") {
            amountString += "."
        }
    }

    private func backspace() {
        guard !amountString.isEmpty else { return }
        amountString.removeLast()
    }

    // Step 2 — Where
    private var whereStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Where?")
                    .font(.system(size: Theme.FontSize.s13))
                    .foregroundStyle(Theme.Color.textMuted)
                TextField("Trader Joe's", text: $merchant)
                    .font(.system(size: Theme.FontSize.s15))
                    .foregroundStyle(Theme.Color.text)
                    .padding(.vertical, Theme.Spacing.s12)
                    .padding(.horizontal, Theme.Spacing.s14)
                    .background(Theme.Color.hoverFill)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            }

            let recents = store.recentMerchants()
            if !recents.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("RECENT")
                        .font(.system(size: Theme.FontSize.s11))
                        .tracking(0.5)
                        .foregroundStyle(Theme.Color.textFaint)

                    FlowLayout(spacing: 8) {
                        ForEach(recents, id: \.self) { name in
                            Button {
                                merchant = name
                            } label: {
                                Text(name)
                                    .font(.system(size: Theme.FontSize.s13))
                                    .foregroundStyle(Theme.Color.textSecondary)
                                    .padding(.vertical, 7)
                                    .padding(.horizontal, 12)
                                    .overlay(Capsule().strokeBorder(Theme.Color.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.gutter)
        .padding(.top, Theme.Spacing.s20)
    }

    // Step 3 — Budget
    private var budgetStep: some View {
        ScrollView {
            VStack(spacing: 0) {
                Button {
                    isAddingBudget = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("New budget")
                            .font(.system(size: Theme.FontSize.s15))
                    }
                    .foregroundStyle(Theme.Color.accentText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Theme.Spacing.s14)
                    .padding(.horizontal, Theme.Spacing.gutter)
                }
                .buttonStyle(.plain)

                ForEach(store.budgets) { budget in
                    Button {
                        selectedBudgetID = budget.id
                    } label: {
                        budgetPickerRow(budget)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func budgetPickerRow(_ budget: Budget) -> some View {
        let remaining = store.remaining(budget, in: store.currentMonth)
        let isSelected = selectedBudgetID == budget.id

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(budget.name)
                    .font(.system(size: Theme.FontSize.s15))
                    .foregroundStyle(Theme.Color.text)
                Text(budget.group.rawValue)
                    .font(.system(size: Theme.FontSize.s12))
                    .foregroundStyle(Theme.Color.textFaint)
            }
            Spacer()
            Text(Money.remainingString(remaining))
                .font(.system(size: Theme.FontSize.s13))
                .foregroundStyle(remaining < 0 ? Theme.Color.negative : Theme.Color.textMuted)
                .monospacedDigit()
        }
        .padding(.vertical, Theme.Spacing.s14)
        .padding(.horizontal, Theme.Spacing.gutter)
        .background(isSelected ? Theme.Color.accentTint : .clear)
    }

    // Step 4 — Review
    private var reviewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.s20) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s10) {
                    reviewRow(label: "Amount", value: Money.string(amount))
                    reviewRow(label: "Where", value: displayedMerchant)
                    reviewRow(label: "Budget", value: selectedBudget?.name ?? "")
                }
                .padding(Theme.Spacing.s16)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Color.border, lineWidth: 1))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Note")
                        .font(.system(size: Theme.FontSize.s13))
                        .foregroundStyle(Theme.Color.textMuted)
                    TextField("", text: $note)
                        .font(.system(size: Theme.FontSize.s15))
                        .foregroundStyle(Theme.Color.text)
                        .padding(.vertical, Theme.Spacing.s12)
                        .padding(.horizontal, Theme.Spacing.s14)
                        .background(Theme.Color.hoverFill)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                }

                if let budget = selectedBudget {
                    Text(consequenceText(for: budget))
                        .font(.system(size: Theme.FontSize.s13))
                        .foregroundStyle(consequenceOverspends(for: budget) ? Theme.Color.negative : Theme.Color.textSecondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.top, Theme.Spacing.s20)
        }
    }

    private var displayedMerchant: String {
        let trimmed = merchant.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? (selectedBudget?.name ?? "") : trimmed
    }

    private func reviewRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Theme.Color.textMuted)
            Spacer()
            Text(value)
                .foregroundStyle(Theme.Color.text)
                .monospacedDigit()
        }
        .font(.system(size: Theme.FontSize.s15))
    }

    private func remainingAfter(_ budget: Budget) -> Decimal {
        store.remaining(budget, in: store.currentMonth) - amount
    }

    private func consequenceOverspends(for budget: Budget) -> Bool {
        remainingAfter(budget) < 0
    }

    private func consequenceText(for budget: Budget) -> String {
        let after = remainingAfter(budget)
        if after < 0 {
            return "\(budget.name) goes \(Money.string(after.magnitude)) over budget."
        } else {
            return "\(Money.string(after)) left in \(budget.name) after this."
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.Color.hairline).frame(height: 1)
            GeometryReader { geo in
                HStack(spacing: 10) {
                    if step > 0 {
                        Button {
                            step -= 1
                        } label: {
                            Text("Back")
                                .font(.system(size: Theme.FontSize.s15))
                                .foregroundStyle(Theme.Color.rowPrimary)
                        }
                        .buttonStyle(.plain)
                        .frame(width: geo.size.width * 0.34, height: geo.size.height)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Color.border, lineWidth: 1))
                    }

                    Button(action: primaryAction) {
                        Text(step == 3 ? "Save" : "Next")
                            .font(.system(size: Theme.FontSize.s15))
                            .foregroundStyle(isStepSatisfied ? Theme.Color.accent : Theme.Color.disabledInk)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .frame(height: geo.size.height)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .strokeBorder(isStepSatisfied ? Theme.Color.accent : Theme.Color.border, lineWidth: 1)
                    )
                }
            }
            .frame(height: 48)
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.top, Theme.Spacing.s12)
            .padding(.bottom, Theme.Spacing.s28)
        }
    }

    private func primaryAction() {
        guard isStepSatisfied else { return }
        if step < 3 {
            step += 1
        } else {
            save()
        }
    }

    private func save() {
        guard let budgetID = selectedBudgetID else { return }
        let transaction = Transaction(
            date: BudgetStore.referenceDate,
            merchant: displayedMerchant,
            budgetID: budgetID,
            amount: amount,
            note: note
        )
        store.add(transaction)
        onSaved(budgetID)
    }
}

/// Minimal wrapping layout for the "RECENT" merchant chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        y += rowHeight
        return CGSize(width: width.isFinite ? width : x, height: y)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
