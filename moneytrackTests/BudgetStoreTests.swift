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

    func createBudget(name: String, group: BudgetGroup, cap: Decimal, month: String) async throws -> BudgetWithCap { throw APIError.invalidRequest }
    func updateBudget(id: UUID, name: String?, group: BudgetGroup?) async throws -> Budget { throw APIError.invalidRequest }
    func deleteBudget(id: UUID) async throws { throw APIError.invalidRequest }
    func setCap(budgetID: UUID, month: String, amount: Decimal) async throws -> Decimal { throw APIError.invalidRequest }
    func createTransaction(date: Date, merchant: String, budgetID: UUID, amount: Decimal, note: String) async throws -> Transaction { throw APIError.invalidRequest }
    func updateTransaction(_ transaction: Transaction) async throws -> Transaction { throw APIError.invalidRequest }
    func deleteTransaction(id: UUID) async throws { throw APIError.invalidRequest }
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

    @Test func aServerErrorMessageIsShown() async {
        let (api, store) = fixture()
        api.error = .server(status: 500, message: "Internal Server Error")
        await store.loadViewedMonth()
        #expect(store.status == .failed("Internal Server Error"))
    }
}
