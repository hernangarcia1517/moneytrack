//
//  SpendingView.swift
//  moneytrack
//

import SwiftUI

struct SpendingView: View {
    @Environment(BudgetStore.self) private var store

    /// Set by tapping a transaction row; ContentView observes this and
    /// presents AddTransactionView in edit mode — same cross-view pattern
    /// PlanView uses for `groupToExpand`.
    @Binding var transactionToEdit: Transaction?

    @State private var openTransactionID: Transaction.ID?
    @State private var scrubbedDay: Int?

    private var month: DateInterval { store.currentMonth }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    MonthHeader()

                    VStack(alignment: .leading, spacing: 0) {
                        chartHeadline
                            .padding(.top, Theme.Spacing.s14)
                            .padding(.bottom, Theme.Spacing.s18)

                        DailyBars(
                            dailyTotals: dailyTotals,
                            elapsedDayOfMonth: min(store.elapsedDayOfMonth, daysInMonth),
                            axisStartLabel: axisLabel(forDay: 1),
                            axisEndLabel: axisLabel(forDay: daysInMonth),
                            scrubbedDay: $scrubbedDay
                        )
                    }
                    .padding(.horizontal, Theme.Spacing.gutter)
                    .padding(.bottom, Theme.Spacing.s16)

                    FadingRule()
                        .padding(.horizontal, Theme.Spacing.gutter)

                    if groupedByDay.isEmpty {
                        Text("Nothing logged yet this month.")
                            .font(.system(size: Theme.FontSize.s14))
                            .foregroundStyle(Theme.Color.textFaint)
                            .padding(.vertical, 60)
                            .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(groupedByDay, id: \.date) { day in
                                daySection(day)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.gutter)
                    }
                }
            }
            .background(Theme.Color.background)
        }
    }

    // MARK: - Chart headline

    /// 13pt label above the headline figure: "Day-to-day in March", or the
    /// scrubbed day's date while dragging over the chart.
    private var chartHeadline: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(scrubLabel)
                .font(.system(size: Theme.FontSize.s13))
                .foregroundStyle(Theme.Color.neutral400)
            Text(Money.string(scrubbedDay != nil ? scrubbedDayTotal : dayToDayTotal))
                .font(.system(size: Theme.FontSize.s32, weight: .medium))
                .tracking(Theme.FontSize.s32 * -0.025)
                .foregroundStyle(Theme.Color.neutral100)
                .monospacedDigit()
            Text(scrubNote)
                .font(.system(size: Theme.FontSize.s11))
                .foregroundStyle(Theme.Color.neutral600)
        }
    }

    private var scrubLabel: String {
        guard let scrubbedDay else { return "Day-to-day in \(monthName)" }
        return "\(monthName) \(scrubbedDay.withOrdinalSuffix)"
    }

    /// Bills are excluded from the day-to-day figure (fixed, not a "how am
    /// I spending day to day" signal) — the note makes that explicit, and
    /// includes the true month total (incl. Bills) only in the resting
    /// (non-scrubbed) state, matching the design.
    private var scrubNote: String {
        guard scrubbedDay == nil else { return "Excludes fixed bills" }
        return "Excludes fixed bills · \(Money.string(store.totalSpent(in: month))) spent in all"
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.calendar = .gregorian
        formatter.dateFormat = "LLLL"
        return formatter.string(from: month.start)
    }

    private func axisLabel(forDay day: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .gregorian
        formatter.dateFormat = "MMM"
        let monthAbbrev = formatter.string(from: month.start)
        return "\(monthAbbrev) \(day)"
    }

    // MARK: - Chart data

    private var daysInMonth: Int {
        Calendar.gregorian.range(of: .day, in: .month, for: month.start)?.count ?? 30
    }

    /// The day-to-day chart excludes Bills-group spend entirely — fixed
    /// bills would otherwise dominate the scale and obscure the
    /// discretionary day-to-day pattern the chart exists to show.
    private var nonBillsTransactions: [Transaction] {
        store.transactions(in: month).filter { store.budget(for: $0.budgetID)?.group != .bills }
    }

    /// One entry per day of the month (not just elapsed days — later days
    /// render as dim "future" stubs in DailyBars).
    private var dailyTotals: [Decimal] {
        var totals = [Decimal](repeating: 0, count: daysInMonth)
        let calendar = Calendar.gregorian
        for transaction in nonBillsTransactions {
            let day = calendar.component(.day, from: transaction.date)
            guard day >= 1, day <= totals.count else { continue }
            totals[day - 1] += transaction.amount
        }
        return totals
    }

    private var dayToDayTotal: Decimal {
        nonBillsTransactions.reduce(0) { $0 + $1.amount }
    }

    private var scrubbedDayTotal: Decimal {
        guard let scrubbedDay, scrubbedDay >= 1, scrubbedDay <= dailyTotals.count else { return 0 }
        return dailyTotals[scrubbedDay - 1]
    }

    // MARK: - Transaction list

    private struct DayGroup {
        let date: Date
        let transactions: [Transaction]
        var total: Decimal { transactions.reduce(0) { $0 + $1.amount } }
    }

    private var groupedByDay: [DayGroup] {
        let calendar = Calendar.gregorian
        let byDay = Dictionary(grouping: store.transactions(in: month)) {
            calendar.startOfDay(for: $0.date)
        }
        return byDay.keys.sorted(by: >).map { date in
            let transactions = (byDay[date] ?? []).sorted { $0.date > $1.date }
            return DayGroup(date: date, transactions: transactions)
        }
    }

    private func daySection(_ day: DayGroup) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(Self.dayHeaderLabel(day.date))
                Spacer()
                Text(Money.string(day.total))
                    .monospacedDigit()
            }
            .font(.system(size: Theme.FontSize.s11))
            .tracking(0.5)
            .foregroundStyle(Theme.Color.textFaint)
            .padding(.top, Theme.Spacing.s20)
            .padding(.bottom, Theme.Spacing.s10)

            ForEach(day.transactions) { transaction in
                transactionRow(transaction)
            }
        }
    }

    private func transactionRow(_ transaction: Transaction) -> some View {
        SwipeToDeleteRow(
            id: transaction.id,
            openID: $openTransactionID,
            onTap: { transactionToEdit = transaction },
            onDelete: { store.delete(transaction) }
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.merchant)
                        .font(.system(size: Theme.FontSize.s15))
                        .foregroundStyle(Theme.Color.emphasis)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(store.budget(for: transaction.budgetID)?.name ?? "")
                        .font(.system(size: Theme.FontSize.s12))
                        .foregroundStyle(Theme.Color.textFaint)
                }
                Spacer(minLength: Theme.Spacing.s12)
                Text(Money.string(transaction.amount))
                    .font(.system(size: Theme.FontSize.s15))
                    .foregroundStyle(Theme.Color.text)
                    .monospacedDigit()
            }
            .padding(.vertical, 9)
        }
    }

    private static func dayHeaderLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .gregorian
        formatter.dateFormat = "LLLL"
        let month = formatter.string(from: date).uppercased()
        let day = Calendar.gregorian.component(.day, from: date)
        return "\(month) \(day.withOrdinalSuffix.uppercased())"
    }
}
