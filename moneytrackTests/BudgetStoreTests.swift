import Foundation
import Testing
@testable import moneytrack

private final class FakeAPI: MoneytrackAPI {
    var budgetsByMonth: [String: [BudgetWithCap]] = [:]
    var transactionsByMonth: [String: [Transaction]] = [:]
    var error: APIError?
    var delay: Duration?
    private(set) var requestedMonths: [String] = []

    func budgets(month: String) async throws -> [BudgetWithCap] {
        requestedMonths.append(month)
        if let delay { try await Task.sleep(for: delay) }
        if let error { throw error }
        return budgetsByMonth[month] ?? []
    }

    func transactions(month: String) async throws -> [Transaction] {
        if let delay { try await Task.sleep(for: delay) }
        if let error { throw error }
        return transactionsByMonth[month] ?? []
    }

    var writeError: APIError?
    var deleteDelay: Duration?
    private(set) var deleteCalls = 0

    func createBudget(name: String, group: BudgetGroup, cap: Decimal, month: String) async throws -> BudgetWithCap {
        if let writeError { throw writeError }
        return BudgetWithCap(budget: Budget(name: name, group: group), cap: cap)
    }

    func updateBudget(id: UUID, name: String?, group: BudgetGroup?) async throws -> Budget {
        if let writeError { throw writeError }
        let existing = budgetsByMonth.values.flatMap { $0 }.first { $0.id == id }!.budget
        return Budget(id: id, name: name ?? existing.name, group: group ?? existing.group)
    }

    func deleteBudget(id: UUID) async throws {
        deleteCalls += 1
        if let deleteDelay { try await Task.sleep(for: deleteDelay) }
        if let writeError { throw writeError }
    }

    func setCap(budgetID: UUID, month: String, amount: Decimal) async throws -> Decimal {
        if let writeError { throw writeError }
        return amount
    }

    func createTransaction(date: Date, merchant: String, budgetID: UUID, amount: Decimal, note: String) async throws -> Transaction {
        if let writeError { throw writeError }
        return Transaction(date: date, merchant: merchant, budgetID: budgetID, amount: amount, note: note)
    }

    func updateTransaction(_ transaction: Transaction) async throws -> Transaction {
        if let writeError { throw writeError }
        return transaction
    }

    func deleteTransaction(id: UUID) async throws {
        deleteCalls += 1
        if let deleteDelay { try await Task.sleep(for: deleteDelay) }
        if let writeError { throw writeError }
    }
}

nonisolated enum FailingWrite: CaseIterable, Sendable {
    case addTransaction, deleteTransaction, addBudget, setCap
}

private func day(_ string: String) -> Date { WireFormat.date(fromDay: string)! }
private func money(_ string: String) -> Decimal { WireFormat.decimal(fromMoney: string)! }

struct BudgetStoreTests {
    private let groceries = Budget(name: "Groceries", group: .needs)
    private let netflix = Budget(name: "Netflix", group: .bills)

    private func fixture() -> (FakeAPI, BudgetStore) {
        let api = FakeAPI()
        api.budgetsByMonth["2026-10"] = [BudgetWithCap(budget: groceries, cap: money("350.00")), BudgetWithCap(budget: netflix, cap: money("15.99"))]
        api.budgetsByMonth["2026-11"] = [BudgetWithCap(budget: groceries, cap: money("450.00")), BudgetWithCap(budget: netflix, cap: money("15.99"))]
        api.transactionsByMonth["2026-10"] = [
            Transaction(date: day("2026-10-31"), merchant: "Trader Joe's", budgetID: groceries.id, amount: money("42.10")),
            Transaction(date: day("2026-10-02"), merchant: "Netflix", budgetID: netflix.id, amount: money("15.99")),
        ]
        api.transactionsByMonth["2026-11"] = [
            Transaction(date: day("2026-11-01"), merchant: "Safeway", budgetID: groceries.id, amount: money("10.00")),
        ]
        let store = BudgetStore(api: api)
        store.setViewedMonth(day("2026-10-15"))
        return (api, store)
    }

    @Test func startsLoadingUntilTheViewedMonthArrives() async {
        let (_, store) = fixture()
        #expect(store.status == .loading)
        await store.loadViewedMonth()
        #expect(store.status == .loaded)
    }

    @Test func loadedMonthAnswersTheDerivedQueries() async {
        let (_, store) = fixture()
        await store.loadViewedMonth()
        let month = store.currentMonth
        #expect(store.budgets.map(\.name).sorted() == ["Groceries", "Netflix"])
        #expect(store.budgetCap(groceries, in: month) == money("350.00"))
        #expect(store.spent(groceries, in: month) == money("42.10"))
        #expect(store.remaining(groceries, in: month) == money("307.90"))
        #expect(store.totalSpent(in: month) == money("58.09"))
        #expect(store.totalPlanned(in: month) == money("365.99"))
        #expect(store.spent(.needs, in: month) == money("42.10"))
        #expect(store.transactions(for: netflix, in: month).count == 1)
    }

    @Test func firstOfNextMonthIsNotInThisMonth() async {
        let (_, store) = fixture()
        await store.loadViewedMonth()
        #expect(store.transactions(in: store.currentMonth).contains { $0.merchant == "Safeway" } == false)
        store.setViewedMonth(day("2026-11-10"))
        await store.loadViewedMonth()
        #expect(store.transactions(in: store.currentMonth).map(\.merchant) == ["Safeway"])
        #expect(store.budgetCap(groceries, in: store.currentMonth) == money("450.00"))
    }

    @Test func monthsStayCachedAfterSwitching() async {
        let (api, store) = fixture()
        await store.loadViewedMonth()
        store.setViewedMonth(day("2026-11-10"))
        #expect(store.status == .loading)
        await store.loadViewedMonth()
        store.setViewedMonth(day("2026-10-10"))
        #expect(store.status == .loaded)
        #expect(api.requestedMonths == ["2026-10", "2026-11"])
        #expect(store.spent(groceries, in: store.currentMonth) == money("42.10"))
    }

    @Test func aMonthWithNoDataIsLoadedNotLoading() async {
        let (_, store) = fixture()
        store.setViewedMonth(day("2030-01-01"))
        await store.loadViewedMonth()
        #expect(store.status == .loaded)
        #expect(store.totalSpent(in: store.currentMonth) == 0)
    }

    @Test func aFailedLoadReportsTheMessageAndRetrySucceeds() async {
        let (api, store) = fixture()
        api.error = .unreachable
        await store.loadViewedMonth()
        #expect(store.status == .failed("Can't reach the server."))
        #expect(store.budgets.isEmpty)

        api.error = nil
        let before = store.reloadToken
        store.retry()
        #expect(store.reloadToken == before + 1)
        await store.loadViewedMonth()
        #expect(store.status == .loaded)
    }

    @Test func aFailedRefreshKeepsTheMonthAlreadyLoaded() async {
        let (api, store) = fixture()
        await store.loadViewedMonth()
        api.error = .unreachable
        await store.loadViewedMonth()
        #expect(store.status == .loaded)
        #expect(store.spent(groceries, in: store.currentMonth) == money("42.10"))
    }

    @Test func aCancelledLoadAppliesNothing() async {
        let (api, store) = fixture()
        api.delay = .seconds(5)
        let task = Task { await store.loadViewedMonth() }
        task.cancel()
        await task.value
        #expect(store.status == .loading)
        #expect(store.budgets.isEmpty)
    }

    // MARK: - Writes

    private func loadedFixture(months: [String] = ["2026-10"]) async -> (FakeAPI, BudgetStore) {
        let (api, store) = fixture()
        for month in months {
            store.setViewedMonth(day("\(month)-15"))
            await store.loadViewedMonth()
        }
        store.setViewedMonth(day("\(months[0])-15"))
        return (api, store)
    }

    @Test func addingATransactionStoresTheServersCopy() async throws {
        let (_, store) = await loadedFixture()
        try await store.addTransaction(date: day("2026-10-20"), merchant: "Costco", budgetID: groceries.id, amount: money("80.00"), note: "")
        #expect(store.transactions(for: groceries, in: store.currentMonth).map(\.merchant).contains("Costco"))
        #expect(store.spent(groceries, in: store.currentMonth) == money("122.10"))
    }

    @Test func aTransactionInAMonthThatIsNotLoadedDoesNotMarkItLoaded() async throws {
        let (_, store) = await loadedFixture()
        try await store.addTransaction(date: day("2026-12-05"), merchant: "Costco", budgetID: groceries.id, amount: money("80.00"), note: "")
        store.setViewedMonth(day("2026-12-05"))
        #expect(store.status == .loading)
    }

    @Test(arguments: FailingWrite.allCases)
    func aFailedWriteChangesNothing(write: FailingWrite) async {
        let (api, store) = await loadedFixture()
        let month = store.currentMonth
        let target = store.transactions(in: month)[0]
        let budgetsBefore = store.budgets
        let idsBefore = store.transactions(in: month).map(\.id)
        let spentBefore = store.totalSpent(in: month)
        let plannedBefore = store.totalPlanned(in: month)

        api.writeError = .unreachable
        await #expect(throws: APIError.unreachable) {
            switch write {
            case .addTransaction:
                try await store.addTransaction(date: day("2026-10-20"), merchant: "Costco", budgetID: groceries.id, amount: money("80.00"), note: "")
            case .deleteTransaction:
                try await store.delete(target)
            case .addBudget:
                _ = try await store.addBudget(name: "Gym", group: .wants, budgetCap: 1)
            case .setCap:
                try await store.setBudgetCap(groceries, to: money("400.00"), in: month)
            }
        }

        #expect(store.budgets == budgetsBefore)
        #expect(store.transactions(in: month).map(\.id) == idsBefore)
        #expect(store.totalSpent(in: month) == spentBefore)
        #expect(store.totalPlanned(in: month) == plannedBefore)
    }

    @Test func editingTheDateMovesATransactionToTheOtherMonth() async throws {
        let (_, store) = await loadedFixture(months: ["2026-10", "2026-11"])
        let october = store.transactions(in: store.currentMonth).first { $0.merchant == "Netflix" }!
        var moved = october
        moved.date = day("2026-11-02")
        try await store.update(moved)
        #expect(store.transactions(in: store.currentMonth).contains { $0.id == october.id } == false)
        store.setViewedMonth(day("2026-11-10"))
        #expect(store.transactions(in: store.currentMonth).contains { $0.id == october.id })
    }

    @Test func deletingATransactionRemovesItAfterTheServerAgrees() async throws {
        let (_, store) = await loadedFixture()
        let target = store.transactions(in: store.currentMonth)[0]
        try await store.delete(target)
        #expect(store.transactions(in: store.currentMonth).contains { $0.id == target.id } == false)
    }

    @Test func deletingSomethingAlreadyGoneCountsAsDeleted() async throws {
        let (api, store) = await loadedFixture()
        let target = store.transactions(in: store.currentMonth)[0]
        api.writeError = .server(status: 404, message: "Transaction not found")
        try await store.delete(target)
        #expect(store.transactions(in: store.currentMonth).contains { $0.id == target.id } == false)
    }

    @Test func deletingTheSameThingTwiceAtOnceSendsOneRequest() async throws {
        let (api, store) = await loadedFixture()
        api.deleteDelay = .milliseconds(100)
        let target = store.transactions(in: store.currentMonth)[0]
        async let first: Void = store.delete(target)
        async let second: Void = store.delete(target)
        _ = try await (first, second)
        #expect(api.deleteCalls == 1)
    }

    @Test func aNewBudgetIsSortedInAndGetsItsCapInEveryLoadedMonth() async throws {
        let (_, store) = await loadedFixture(months: ["2026-10", "2026-11"])
        let created = try await store.addBudget(name: "  Gym ", group: .wants, budgetCap: money("30.00"))
        #expect(created.name == "Gym")
        #expect(store.budgets.map(\.name) == ["Groceries", "Gym", "Netflix"])
        #expect(store.budgetCap(created, in: store.currentMonth) == money("30.00"))
        store.setViewedMonth(day("2026-11-10"))
        #expect(store.budgetCap(created, in: store.currentMonth) == money("30.00"))
    }

    @Test func movingABudgetUsesTheServersAnswer() async throws {
        let (_, store) = await loadedFixture()
        try await store.move(netflix, to: .wants)
        #expect(store.budgets.first { $0.id == netflix.id }?.group == .wants)
        #expect(store.spent(.wants, in: store.currentMonth) == money("15.99"))
    }

    @Test func aCapEditUpdatesThisMonthAndDropsTheOtherLoadedMonths() async throws {
        let (_, store) = await loadedFixture(months: ["2026-10", "2026-11"])
        try await store.setBudgetCap(groceries, to: money("400.00"), in: store.currentMonth)
        #expect(store.budgetCap(groceries, in: store.currentMonth) == money("400.00"))
        #expect(store.status == .loaded)
        store.setViewedMonth(day("2026-11-10"))
        #expect(store.status == .loading)
        await store.loadViewedMonth()
        #expect(store.budgetCap(groceries, in: store.currentMonth) == money("450.00"))
    }

    @Test func deletingABudgetRemovesItsTransactionsAndCaps() async throws {
        let (_, store) = await loadedFixture(months: ["2026-10", "2026-11"])
        try await store.deleteBudget(groceries)
        #expect(store.budgets.map(\.name) == ["Netflix"])
        #expect(store.transactions(in: store.currentMonth).allSatisfy { $0.budgetID != groceries.id })
        #expect(store.totalPlanned(in: store.currentMonth) == money("15.99"))
        store.setViewedMonth(day("2026-11-10"))
        #expect(store.transactions(in: store.currentMonth).isEmpty)
    }

    @Test func aFailedWriteStartedThroughAttemptRaisesTheAlert() async {
        let (api, store) = await loadedFixture()
        api.writeError = .unreachable
        store.attempt { try await store.move(netflix, to: .wants) }
        for _ in 0..<50 where store.alertMessage == nil { try? await Task.sleep(for: .milliseconds(10)) }
        #expect(store.alertMessage == "Can't reach the server.")
        store.dismissAlert()
        #expect(store.alertMessage == nil)
    }
}
