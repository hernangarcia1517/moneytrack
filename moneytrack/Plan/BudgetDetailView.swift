//
//  BudgetDetailView.swift
//  moneytrack
//
//  Pushed from a Plan row. A drill-down, not a modal — the tab bar stays
//  visible underneath.
//

import SwiftUI

struct BudgetDetailView: View {
    @Environment(BudgetStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let budget: Budget
    var groupToExpand: Binding<BudgetGroup?> = .constant(nil)

    @State private var capText: String = ""
    @State private var isConfirmingDelete = false

    private var month: DateInterval { store.currentMonth }

    /// The store is the source of truth; re-read the live copy so edits
    /// (cap, group) are reflected immediately.
    private var live: Budget { store.budgets.first(where: { $0.id == budget.id }) ?? budget }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                backButton
                    .padding(.top, Theme.Spacing.s14)

                Text(live.name)
                    .font(.system(size: Theme.FontSize.s26, weight: .medium))
                    .foregroundStyle(Theme.Color.text)
                    .padding(.top, Theme.Spacing.s20)

                stats
                    .padding(.top, Theme.Spacing.s20)

                ProgressTrack(fraction: fraction, isOver: isOver, height: 6)
                    .padding(.top, Theme.Spacing.s12)

                capField
                    .padding(.top, Theme.Spacing.s26)

                groupChips
                    .padding(.top, Theme.Spacing.s20)

                transactionsSection
                    .padding(.top, Theme.Spacing.s26)

                deleteButton
                    .padding(.top, Theme.Spacing.s28)
                    .padding(.bottom, Theme.Spacing.s28)
            }
            .padding(.horizontal, Theme.Spacing.gutter)
        }
        .background(Theme.Color.background)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { capText = Self.capString(live.monthlyCap) }
    }

    // MARK: - Sections

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 8, height: 13)
                Text("Back")
                    .font(.system(size: Theme.FontSize.s15))
            }
            .foregroundStyle(Theme.Color.accentText)
        }
        .buttonStyle(.plain)
    }

    private var stats: some View {
        HStack(spacing: 28) {
            stat(label: "SPENT", value: Money.string(spent), color: Theme.Color.text)
            stat(
                label: "LEFT",
                value: remaining < 0 ? "\(Money.string(remaining)) over" : Money.string(remaining),
                color: remaining < 0 ? Theme.Color.negative : Theme.Color.text
            )
        }
    }

    private func stat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: Theme.FontSize.s11))
                .tracking(0.5)
                .foregroundStyle(Theme.Color.textFaint)
            Text(value)
                .font(.system(size: Theme.FontSize.s22))
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }

    private var capField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly budget")
                .font(.system(size: Theme.FontSize.s13))
                .foregroundStyle(Theme.Color.textMuted)

            TextField("", text: $capText)
                .keyboardType(.decimalPad)
                .font(.system(size: Theme.FontSize.s15))
                .foregroundStyle(Theme.Color.text)
                .padding(.vertical, Theme.Spacing.s12)
                .padding(.horizontal, Theme.Spacing.s14)
                .background(Theme.Color.hoverFill)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                .onChange(of: capText) { _, newValue in
                    let filtered = Self.filterDecimalInput(newValue)
                    if filtered != newValue { capText = filtered }
                    if let cap = Decimal(string: filtered), cap != live.monthlyCap {
                        store.setCap(live, to: cap)
                    }
                }
        }
    }

    private var groupChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GROUP")
                .font(.system(size: Theme.FontSize.s11))
                .tracking(0.5)
                .foregroundStyle(Theme.Color.textFaint)

            HStack(spacing: 8) {
                ForEach(BudgetGroup.allCases) { group in
                    GroupChip(title: group.rawValue, isSelected: live.group == group) {
                        guard live.group != group else { return }
                        store.move(live, to: group)
                        groupToExpand.wrappedValue = group
                    }
                }
            }
        }
    }

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("THIS MONTH")
                .font(.system(size: Theme.FontSize.s11))
                .tracking(0.5)
                .foregroundStyle(Theme.Color.textFaint)
                .padding(.bottom, Theme.Spacing.s12)

            let rows = store.transactions(for: live, in: month).sorted { $0.date > $1.date }
            ForEach(rows) { transaction in
                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(transaction.merchant)
                                .font(.system(size: Theme.FontSize.s15))
                                .foregroundStyle(Theme.Color.text)
                            Text(Self.dayString(transaction.date))
                                .font(.system(size: Theme.FontSize.s12))
                                .foregroundStyle(Theme.Color.textFaint)
                        }
                        Spacer()
                        Text(Money.string(transaction.amount))
                            .font(.system(size: Theme.FontSize.s15))
                            .foregroundStyle(Theme.Color.text)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 12)

                    if transaction.id != rows.last?.id {
                        Rectangle().fill(Theme.Color.hairline).frame(height: 1)
                    }
                }
            }
        }
    }

    private var deleteButton: some View {
        Button {
            isConfirmingDelete = true
        } label: {
            Text(deleteLabel)
                .font(.system(size: Theme.FontSize.s13))
                .foregroundStyle(Theme.Color.negative)
        }
        .buttonStyle(.plain)
        .confirmationDialog(deleteLabel, isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button(deleteLabel, role: .destructive) {
                store.deleteBudget(live)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Derived

    private var spent: Decimal { store.spent(live, in: month) }
    private var remaining: Decimal { store.remaining(live, in: month) }
    private var isOver: Bool { remaining < 0 }

    private var fraction: Double {
        guard live.monthlyCap > 0 else { return spent > 0 ? 1 : 0 }
        let value = NSDecimalNumber(decimal: spent / live.monthlyCap).doubleValue
        return min(max(value, 0), 1)
    }

    private var deleteLabel: String {
        let count = store.transactionCount(for: live)
        return count > 0 ? "Delete budget and its \(count) transaction\(count == 1 ? "" : "s")" : "Delete budget"
    }

    private static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .gregorian
        formatter.dateFormat = "LLLL"
        let month = formatter.string(from: date)
        let day = Calendar.gregorian.component(.day, from: date)
        return "\(month) \(day.withOrdinalSuffix)"
    }

    private static func capString(_ amount: Decimal) -> String {
        var value = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        return NSDecimalNumber(decimal: rounded).stringValue
    }

    private static func filterDecimalInput(_ input: String) -> String {
        var seenDecimal = false
        return String(input.filter { character in
            if character == "." {
                if seenDecimal { return false }
                seenDecimal = true
                return true
            }
            return character.isNumber
        })
    }
}

/// The pill-shaped group selector shared by BudgetDetailView (auto-width)
/// and reused, at equal width, by NewBudgetSheet.
struct GroupChip: View {
    let title: String
    let isSelected: Bool
    var fillsWidth: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: Theme.FontSize.s15))
                .foregroundStyle(isSelected ? Theme.Color.accentTextOnFill : Theme.Color.textSecondary)
                .padding(.vertical, 7)
                .padding(.horizontal, 15)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .background(isSelected ? Theme.Color.accentTint : .clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(isSelected ? Theme.Color.accent : Theme.Color.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
