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

    @ObservationIgnored private let persistence = BudgetStorePersistence()
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init() {
        if let loaded = persistence.load() {
            budgets = loaded.budgets
            transactions = loaded.transactions
        } else {
            let seed = BudgetStore.seedData()
            budgets = seed.budgets
            transactions = seed.transactions
        }
    }

    // MARK: - Month

    /// There is no month picker yet (explicitly not designed), and the
    /// mock data is anchored to March 2026, so "the current month" is
    /// pinned there for now rather than read from the device clock.
    /// Swap this for a real, user-navigable month once that screen exists.
    static let referenceDate: Date = {
        Calendar.gregorian.date(from: DateComponents(year: 2026, month: 3, day: 16))!
    }()

    var currentMonth: DateInterval {
        Calendar.gregorian.dateInterval(of: .month, for: BudgetStore.referenceDate)!
    }

    /// Elapsed days shown by the Spending daily chart: 1...16 for the
    /// pinned reference date.
    var elapsedDayOfMonth: Int {
        Calendar.gregorian.component(.day, from: BudgetStore.referenceDate)
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
