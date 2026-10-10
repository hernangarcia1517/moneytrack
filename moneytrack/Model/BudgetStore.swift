//
//  BudgetStore.swift
//  moneytrack
//
//  Single source of truth, injected into the environment. Views own only
//  ephemeral UI state (which step of Add they're on, which group is
//  expanded, etc.) — everything about budgets and transactions lives here.
//
//  Data comes from the server one month at a time and is cached per month,
//  keyed by `Budget.monthKey(for:)`. Nothing derived is ever stored: group
//  totals, remaining amounts, the headline figure and the daily bars are all
//  computed from the cached transactions, budgets and caps on read.
//

import Foundation
import Observation

enum LoadStatus: Equatable {
    case loading
    case loaded
    case failed(String)
}

@Observable
final class BudgetStore {
    private(set) var budgets: [Budget] = []
    private var transactionsByMonth: [String: [Transaction]] = [:]
    private var capsByMonth: [String: [Budget.ID: Decimal]] = [:]
    private var loadError: Error?

    /// Bumped by `retry()`; the view that drives loading restarts it when this changes.
    private(set) var reloadToken = 0

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

    @ObservationIgnored private let api: any MoneytrackAPI

    init(api: any MoneytrackAPI = LiveMoneytrackAPI()) {
        self.api = api
        viewedMonth = Calendar.gregorian.dateInterval(of: .month, for: BudgetStore.referenceDate)!.start
    }

    // MARK: - Loading

    private var viewedMonthKey: String { Budget.monthKey(for: viewedMonth) }

    var status: LoadStatus {
        let key = viewedMonthKey
        if transactionsByMonth[key] != nil, capsByMonth[key] != nil { return .loaded }
        if let loadError { return .failed(loadError.localizedDescription) }
        return .loading
    }

    /// Fetches the viewed month's budgets, caps and transactions together and
    /// replaces that month's cache. A cancelled load (the user moved to another
    /// month) applies nothing.
    func loadViewedMonth() async {
        let key = viewedMonthKey
        loadError = nil
        do {
            async let fetchedBudgets = api.budgets(month: key)
            async let fetchedTransactions = api.transactions(month: key)
            let (budgetList, transactionList) = try await (fetchedBudgets, fetchedTransactions)
            guard !Task.isCancelled else { return }
            budgets = budgetList.map(\.budget)
            capsByMonth[key] = Dictionary(budgetList.map { ($0.id, $0.cap) }, uniquingKeysWith: { $1 })
            transactionsByMonth[key] = transactionList
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            loadError = error
        }
    }

    func retry() {
        reloadToken += 1
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
        transactionsByMonth[Budget.monthKey(for: month.start)] ?? []
    }

    func transactions(for budget: Budget, in month: DateInterval) -> [Transaction] {
        transactions(in: month).filter { $0.budgetID == budget.id }
    }

    func spent(_ budget: Budget, in month: DateInterval) -> Decimal {
        transactions(for: budget, in: month).reduce(0) { $0 + $1.amount }
    }

    /// The cap in effect for `budget` during `month`, as the server resolved it.
    func budgetCap(_ budget: Budget, in month: DateInterval) -> Decimal {
        capsByMonth[Budget.monthKey(for: month.start)]?[budget.id] ?? 0
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

    // MARK: - Mutations (local only until the write step: they change the cached
    // months in memory and are lost on the next load)

    func add(_ transaction: Transaction) {
        transactionsByMonth[Budget.monthKey(for: transaction.date)]?.append(transaction)
    }

    func update(_ transaction: Transaction) {
        delete(transaction)
        add(transaction)
    }

    func delete(_ transaction: Transaction) {
        for key in Array(transactionsByMonth.keys) {
            transactionsByMonth[key]?.removeAll { $0.id == transaction.id }
        }
    }

    @discardableResult
    func addBudget(name: String, group: BudgetGroup, budgetCap: Decimal) -> Budget {
        let budget = Budget(name: name.trimmingCharacters(in: .whitespaces), group: group)
        budgets.append(budget)
        for key in Array(capsByMonth.keys) {
            capsByMonth[key]?[budget.id] = budgetCap
        }
        return budget
    }

    /// Applies from `month` onward, like the server.
    func setBudgetCap(_ budget: Budget, to budgetCap: Decimal, in month: DateInterval) {
        let from = Budget.monthKey(for: month.start)
        for key in Array(capsByMonth.keys) where key >= from {
            capsByMonth[key]?[budget.id] = budgetCap
        }
    }

    func move(_ budget: Budget, to group: BudgetGroup) {
        guard let index = budgets.firstIndex(where: { $0.id == budget.id }) else { return }
        budgets[index].group = group
    }

    /// Deleting a budget cascades to its transactions.
    func deleteBudget(_ budget: Budget) {
        budgets.removeAll { $0.id == budget.id }
        for key in Array(transactionsByMonth.keys) {
            transactionsByMonth[key]?.removeAll { $0.budgetID == budget.id }
        }
        for key in Array(capsByMonth.keys) {
            capsByMonth[key]?[budget.id] = nil
        }
    }
}

extension Calendar {
    static let gregorian = Calendar(identifier: .gregorian)
}
