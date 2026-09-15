//
//  AddTransactionView.swift
//  moneytrack
//
//  Presented full-screen (not a sheet — an explicit design change) from the
//  centre "+" button, or in edit mode from tapping a transaction row on
//  Spending. Nothing is written to the store until Save/"Save changes" on
//  the Review step.
//
//  New vs. edit mode differ in a few ways (mirrors the design prototype):
//  - New starts on step 0 (Amount) and walks 0->1->2->3 linearly.
//  - Edit starts directly on step 3 (Review); jumping to an earlier step
//    from a Review row is a single-field mini-editor — "Next" there just
//    returns to Review ("Done"), it doesn't advance the whole flow.
//  - The header title is "Edit transaction" in edit mode (except on the
//    "When?" date step, which always uses its own title), and the 4-dot
//    progress indicator only shows for the new-transaction flow.
//

import SwiftUI

struct AddTransactionView: View {
    @Environment(BudgetStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// nil = adding a new transaction; set = editing this existing one.
    let editingTransaction: Transaction?

    /// Called after the transaction is saved, with the budget it landed in,
    /// so the caller can auto-expand that group on Plan.
    var onSaved: (Budget.ID) -> Void

    @State private var step: Int
    @State private var amountString: String
    @State private var merchant: String
    @State private var selectedBudgetID: Budget.ID?
    @State private var note: String
    @State private var selectedDay: Int
    @State private var isAddingBudget = false

    private static let titles = ["Amount", "Where", "Budget", "Review"]

    init(editing transaction: Transaction? = nil, onSaved: @escaping (Budget.ID) -> Void) {
        self.editingTransaction = transaction
        self.onSaved = onSaved
        if let transaction {
            _step = State(initialValue: 3)
            _amountString = State(initialValue: Self.inputString(for: transaction.amount))
            _merchant = State(initialValue: transaction.merchant)
            _selectedBudgetID = State(initialValue: transaction.budgetID)
            _note = State(initialValue: transaction.note)
            _selectedDay = State(initialValue: Calendar.gregorian.component(.day, from: transaction.date))
        } else {
            _step = State(initialValue: 0)
            _amountString = State(initialValue: "")
            _merchant = State(initialValue: "")
            _selectedBudgetID = State(initialValue: nil)
            _note = State(initialValue: "")
            // Corrected in .onAppear to store.elapsedDayOfMonth — the store
            // isn't available yet inside init().
            _selectedDay = State(initialValue: 1)
        }
    }

    private var isEditing: Bool { editingTransaction != nil }
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
        .onAppear {
            if !isEditing {
                selectedDay = store.elapsedDayOfMonth
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .foregroundStyle(Theme.Color.textMuted)

            Spacer()

            Text(headerTitle)
                .font(.system(size: Theme.FontSize.s15, weight: .medium))
                .foregroundStyle(Theme.Color.text)

            Spacer()

            HStack(spacing: 5) {
                if showsProgressDots {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(dotColor(for: i))
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .frame(minWidth: 35, alignment: .trailing)
        }
        .font(.system(size: Theme.FontSize.s15))
        .padding(.horizontal, Theme.Spacing.gutter)
        .padding(.top, Theme.Spacing.s14)
        .padding(.bottom, Theme.Spacing.s10)
    }

    private var headerTitle: String {
        if step == 4 { return "When?" }
        if isEditing { return "Edit transaction" }
        return Self.titles[step]
    }

    private var showsProgressDots: Bool {
        !isEditing && step < 4
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
        case 3: reviewStep
        default: whenStep
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
                VStack(spacing: 0) {
                    reviewJumpRow(label: "Amount", value: Money.string(amount)) { step = 0 }
                    reviewJumpRow(label: "Where", value: displayedMerchant) { step = 1 }
                    reviewJumpRow(label: "Budget", value: selectedBudget?.name ?? "") { step = 2 }
                    reviewJumpRow(label: "When", value: dayLabel(for: selectedDay), isLast: true) { step = 4 }
                }
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

                if isEditing {
                    Button {
                        deleteEditingTransaction()
                    } label: {
                        Text("Delete transaction")
                            .font(.system(size: Theme.FontSize.s13))
                            .foregroundStyle(Theme.Color.negative)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.top, Theme.Spacing.s20)
        }
    }

    private func reviewJumpRow(label: String, value: String, isLast: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: Theme.FontSize.s13))
                    .foregroundStyle(Theme.Color.textMuted)
                Spacer()
                Text(value)
                    .font(.system(size: Theme.FontSize.s15))
                    .foregroundStyle(Theme.Color.text)
                    .monospacedDigit()
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Color.textFaint)
            }
            .padding(.vertical, Theme.Spacing.s14)
            .padding(.horizontal, Theme.Spacing.s16)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle().fill(Theme.Color.hairline).frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var displayedMerchant: String {
        let trimmed = merchant.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? (selectedBudget?.name ?? "") : trimmed
    }

    private func remainingAfter(_ budget: Budget) -> Decimal {
        let alreadyCounted = editingTransaction?.budgetID == budget.id ? (editingTransaction?.amount ?? 0) : 0
        return store.remaining(budget, in: store.currentMonth) + alreadyCounted - amount
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

    private func deleteEditingTransaction() {
        guard let editingTransaction else { return }
        store.delete(editingTransaction)
        dismiss()
    }

    // Step 5 — When (date, within the viewed month)
    private var whenStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.s14) {
                Text(monthYearLabel)
                    .font(.system(size: Theme.FontSize.s13))
                    .foregroundStyle(Theme.Color.textMuted)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.s6), count: 7), spacing: Theme.Spacing.s6) {
                    ForEach(1...daysInMonth, id: \.self) { day in
                        Button {
                            selectedDay = day
                            step = 3
                        } label: {
                            Text("\(day)")
                                .font(.system(size: Theme.FontSize.s14))
                                .monospacedDigit()
                                .foregroundStyle(day == selectedDay ? Theme.Color.accentText : Theme.Color.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(day == selectedDay ? Theme.Color.accentTint : Theme.Color.hoverFill)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.row))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.top, Theme.Spacing.s20)
        }
    }

    private var daysInMonth: Int {
        Calendar.gregorian.range(of: .day, in: .month, for: store.currentMonth.start)?.count ?? 30
    }

    private var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.calendar = .gregorian
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: store.currentMonth.start)
    }

    private func dayLabel(for day: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .gregorian
        formatter.dateFormat = "LLLL"
        let monthName = formatter.string(from: store.currentMonth.start)
        return "\(monthName) \(day.withOrdinalSuffix)"
    }

    private func date(forDay day: Int) -> Date {
        Calendar.gregorian.date(byAdding: .day, value: day - 1, to: store.currentMonth.start) ?? store.currentMonth.start
    }

    // MARK: - Action bar

    private var actionBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.Color.hairline).frame(height: 1)
            GeometryReader { geo in
                HStack(spacing: 10) {
                    if canGoBack {
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
                        Text(primaryLabel)
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

    /// Back only shows on the "When" step (step 4, both flows) or on steps
    /// 1-3 of the new-transaction flow. In edit mode, jumping from Review to
    /// an earlier field (steps 0-2) is a single-field mini-editor — "Done"
    /// (the primary button) returns to Review, there's no separate Back.
    private var canGoBack: Bool {
        step == 4 || (!isEditing && step > 0)
    }

    private var primaryLabel: String {
        if step == 4 { return "Done" }
        if isEditing { return step == 3 ? "Save changes" : "Done" }
        return step == 3 ? "Save" : "Next"
    }

    private func primaryAction() {
        guard isStepSatisfied else { return }
        if step == 4 {
            step = 3
            return
        }
        if isEditing {
            if step == 3 { save() } else { step = 3 }
            return
        }
        if step == 3 { save() } else { step += 1 }
    }

    private func save() {
        guard let budgetID = selectedBudgetID else { return }
        let date = date(forDay: selectedDay)
        if let editingTransaction {
            store.update(Transaction(
                id: editingTransaction.id,
                date: date,
                merchant: displayedMerchant,
                budgetID: budgetID,
                amount: amount,
                note: note
            ))
        } else {
            store.add(Transaction(
                date: date,
                merchant: displayedMerchant,
                budgetID: budgetID,
                amount: amount,
                note: note
            ))
        }
        onSaved(budgetID)
    }

    private static func inputString(for amount: Decimal) -> String {
        var value = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        return NSDecimalNumber(decimal: rounded).stringValue
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
