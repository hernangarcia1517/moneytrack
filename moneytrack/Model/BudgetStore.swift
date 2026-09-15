//
//  BudgetStore.swift
//  moneytrack
//
//  Single source of truth, injected into the environment. Views own only
//  ephemeral UI state (which step of Add they're on, which group is
//  expanded, etc.) — everything about budgets and transactions lives here.
//
//  Nothing derived is ever stored: group totals, remaining amounts, the
//  headline figure and the daily bars are all computed from
//  `transactions` + `budgets` on read.
//

import Foundation
import Observation

@Observable
final class BudgetStore {
    var budgets: [Budget]
    var transactions: [Transaction]

    /// The month currently being viewed — starts on `referenceDate`'s month
    /// and is user-navigable via the month picker (`MonthPickerSheet`).
    /// Always normalized to the first instant of its month.
    private(set) var viewedMonth: Date

    /// Whether the user has already dismissed the "you're changing a
    /// closed/future month" confirmation for `viewedMonth` this session —
    /// resets whenever `viewedMonth` changes. Matches the design prototype:
    /// only saving/editing a transaction is gated by this, not cap edits or
    /// budget creation.
    private(set) var hasConfirmedOffMonthEdit = false

    @ObservationIgnored private let persistence = BudgetStorePersistence()
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init() {
        viewedMonth = Calendar.gregorian.dateInterval(of: .month, for: BudgetStore.referenceDate)!.start
        if let loaded = persistence.load() {
            budgets = loaded.budgets
            transactions = loaded.transactions
        } else {
            // No mock/seed data — a fresh install (or a wiped local store)
            // starts completely empty; the user adds their own budgets and
            // transactions from here.
            budgets = []
            transactions = []
        }
    }

    // MARK: - Month

    /// The real "today" — the device clock, read fresh on every access
    /// (not cached at launch) so it stays correct if the app is left open
    /// across midnight. Was a fixed simulated date while the app shipped
    /// with mock data anchored to a specific month; now that there's no
    /// seed data, "today" should be genuinely today.
    static var referenceDate: Date {
        Date()
    }

    var currentMonth: DateInterval {
        Calendar.gregorian.dateInterval(of: .month, for: viewedMonth)!
    }

    private var todayMonth: DateInterval {
        Calendar.gregorian.dateInterval(of: .month, for: BudgetStore.referenceDate)!
    }

    var isViewingCurrentMonth: Bool { currentMonth.start == todayMonth.start }
    var isViewingPastMonth: Bool { currentMonth.start < todayMonth.start }
    var isViewingFutureMonth: Bool { currentMonth.start > todayMonth.start }

    /// For the Spending chart's "future day" styling: the real elapsed day
    /// number when viewing the actual current month, every day of the
    /// month when viewing a past month (none of it is "future" anymore), or
    /// zero when viewing a future month (none of it has happened yet).
    var elapsedDayOfMonth: Int {
        if isViewingPastMonth {
            return Calendar.gregorian.range(of: .day, in: .month, for: viewedMonth)?.count ?? 30
        } else if isViewingFutureMonth {
            return 0
        } else {
            return Calendar.gregorian.component(.day, from: BudgetStore.referenceDate)
        }
    }

    /// Day pre-filled when opening Add for a new transaction: real "today"
    /// only while viewing the actual current month, otherwise the 1st —
    /// there's no meaningful "today" inside a month you're not currently in.
    var defaultTransactionDay: Int {
        isViewingCurrentMonth ? Calendar.gregorian.component(.day, from: BudgetStore.referenceDate) : 1
    }

    func setViewedMonth(_ date: Date) {
        viewedMonth = Calendar.gregorian.dateInterval(of: .month, for: date)!.start
        hasConfirmedOffMonthEdit = false
    }

    func goToToday() {
        setViewedMonth(BudgetStore.referenceDate)
    }

    func confirmOffMonthEdit() {
        hasConfirmedOffMonthEdit = true
    }

    // MARK: - Derived (budgets)

    func budgets(in group: BudgetGroup) -> [Budget] {
        budgets.filter { $0.group == group }
    }

    func transactions(in month: DateInterval) -> [Transaction] {
        transactions.filter { month.contains($0.date) }
    }

    func transactions(for budget: Budget, in month: DateInterval) -> [Transaction] {
        transactions(in: month).filter { $0.budgetID == budget.id }
    }

    func spent(_ budget: Budget, in month: DateInterval) -> Decimal {
        transactions(for: budget, in: month).reduce(0) { $0 + $1.amount }
    }

    /// The budget cap in effect for `budget` during `month`: that month's
    /// own override if one has been set, otherwise the budget's base
    /// `monthlyBudgetCap`. Self-contained per month — this never mutates
    /// state, so reading one month never affects another.
    func budgetCap(_ budget: Budget, in month: DateInterval) -> Decimal {
        let key = Budget.monthKey(for: month.start)
        return budget.budgetCapOverrides[key] ?? budget.monthlyBudgetCap
    }

    /// budgetCap - spent, may be negative.
    func remaining(_ budget: Budget, in month: DateInterval) -> Decimal {
        budgetCap(budget, in: month) - spent(budget, in: month)
    }

    func spent(_ group: BudgetGroup, in month: DateInterval) -> Decimal {
        budgets(in: group).reduce(0) { $0 + spent($1, in: month) }
    }

    func remaining(_ group: BudgetGroup, in month: DateInterval) -> Decimal {
        budgets(in: group).reduce(0) { $0 + remaining($1, in: month) }
    }

    func totalSpent(in month: DateInterval) -> Decimal {
        transactions(in: month).reduce(0) { $0 + $1.amount }
    }

    func totalPlanned(in month: DateInterval) -> Decimal {
        budgets.reduce(0) { $0 + budgetCap($1, in: month) }
    }

    func transactionCount(for budget: Budget) -> Int {
        transactions.filter { $0.budgetID == budget.id }.count
    }

    func budget(for id: Budget.ID?) -> Budget? {
        guard let id else { return nil }
        return budgets.first { $0.id == id }
    }

    func isNameTaken(_ name: String, excluding: Budget.ID? = nil) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return budgets.contains {
            $0.id != excluding && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }
    }

    /// The most recent distinct merchants, newest first — used as quick-fill
    /// chips on the "Where" step of Add.
    func recentMerchants(limit: Int = 6) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for t in transactions.sorted(by: { $0.date > $1.date }) {
            let merchant = t.merchant.trimmingCharacters(in: .whitespaces)
            guard !merchant.isEmpty, !seen.contains(merchant.lowercased()) else { continue }
            seen.insert(merchant.lowercased())
            result.append(merchant)
            if result.count == limit { break }
        }
        return result
    }

    // MARK: - Mutations (transactions)

    func add(_ transaction: Transaction) {
        transactions.append(transaction)
        scheduleSave()
    }

    func update(_ transaction: Transaction) {
        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else { return }
        transactions[index] = transaction
        scheduleSave()
    }

    func delete(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
        scheduleSave()
    }

    // MARK: - Mutations (budgets)

    @discardableResult
    func addBudget(name: String, group: BudgetGroup, budgetCap: Decimal) -> Budget {
        let budget = Budget(name: name.trimmingCharacters(in: .whitespaces), group: group, monthlyBudgetCap: budgetCap)
        budgets.append(budget)
        scheduleSave()
        return budget
    }

    /// Sets `budget`'s budget cap for `month` only — every other month
    /// (past or future) keeps whatever value it already resolves to.
    func setBudgetCap(_ budget: Budget, to budgetCap: Decimal, in month: DateInterval) {
        guard let index = budgets.firstIndex(where: { $0.id == budget.id }) else { return }
        let key = Budget.monthKey(for: month.start)
        budgets[index].budgetCapOverrides[key] = budgetCap
        scheduleSave()
    }

    func move(_ budget: Budget, to group: BudgetGroup) {
        guard let index = budgets.firstIndex(where: { $0.id == budget.id }) else { return }
        budgets[index].group = group
        scheduleSave()
    }

    /// Deleting a budget cascades to its transactions.
    func deleteBudget(_ budget: Budget) {
        transactions.removeAll { $0.budgetID == budget.id }
        budgets.removeAll { $0.id == budget.id }
        scheduleSave()
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = (budgets, transactions)
        saveTask = Task {
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            persistence.save(budgets: snapshot.0, transactions: snapshot.1)
        }
    }
}

extension Calendar {
    static let gregorian = Calendar(identifier: .gregorian)
}
