//
//  SpendingView.swift
//  moneytrack
//

import SwiftUI

struct SpendingView: View {
    @Environment(BudgetStore.self) private var store

    private var month: DateInterval { store.currentMonth }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    MonthHeader()

                    VStack(alignment: .leading, spacing: Theme.Spacing.s16) {
                        Text("Daily spend")
                            .font(.system(size: Theme.FontSize.s13))
                            .foregroundStyle(Theme.Color.textMuted)

                        DailyBars(dailyTotals: dailyTotals)
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

    // MARK: - Chart data

    private var dailyTotals: [Decimal] {
        let calendar = Calendar.gregorian
        let transactions = store.transactions(in: month)
        return (1...store.elapsedDayOfMonth).map { day in
            transactions
                .filter { calendar.component(.day, from: $0.date) == day }
                .reduce(0) { $0 + $1.amount }
        }
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

    private static func dayHeaderLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .gregorian
        formatter.dateFormat = "LLLL"
        let month = formatter.string(from: date).uppercased()
        let day = Calendar.gregorian.component(.day, from: date)
        return "\(month) \(day.withOrdinalSuffix.uppercased())"
    }
}
