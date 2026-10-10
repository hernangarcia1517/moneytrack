import Foundation

struct BudgetSummary: Identifiable, Hashable {
    var id: UUID
    var name: String
    var group: BudgetGroup
}

struct BudgetWithCap: Identifiable, Hashable {
    var id: UUID
    var name: String
    var group: BudgetGroup
    var cap: Decimal
}

/// `month` is "YYYY-MM", as produced by `Budget.monthKey(for:)`.
protocol MoneytrackAPI {
    func budgets(month: String) async throws -> [BudgetWithCap]
    func createBudget(name: String, group: BudgetGroup, cap: Decimal, month: String) async throws -> BudgetWithCap
    func updateBudget(id: UUID, name: String?, group: BudgetGroup?) async throws -> BudgetSummary
    func deleteBudget(id: UUID) async throws
    func setCap(budgetID: UUID, month: String, amount: Decimal) async throws -> Decimal

    func transactions(month: String) async throws -> [Transaction]
    func createTransaction(date: Date, merchant: String, budgetID: UUID, amount: Decimal, note: String) async throws -> Transaction
    func updateTransaction(_ transaction: Transaction) async throws -> Transaction
    func deleteTransaction(id: UUID) async throws
}

private extension UUID {
    var pathComponent: String { uuidString.lowercased() }
}

struct LiveMoneytrackAPI: MoneytrackAPI {
    var client = APIClient()

    func budgets(month: String) async throws -> [BudgetWithCap] {
        let dtos: [BudgetDTO] = try await client.get("budgets", query: [URLQueryItem(name: "month", value: month)])
        return try dtos.map { try $0.withCap() }
    }

    func createBudget(name: String, group: BudgetGroup, cap: Decimal, month: String) async throws -> BudgetWithCap {
        let body = CreateBudgetBody(name: name, budgetGroup: group, cap: WireFormat.money(cap), month: month)
        let dto: BudgetDTO = try await client.send(.post, "budgets", body: body)
        return try dto.withCap()
    }

    func updateBudget(id: UUID, name: String?, group: BudgetGroup?) async throws -> BudgetSummary {
        let dto: BudgetDTO = try await client.send(.patch, "budgets/\(id.pathComponent)", body: UpdateBudgetBody(name: name, budgetGroup: group))
        return dto.summary()
    }

    func deleteBudget(id: UUID) async throws {
        try await client.delete("budgets/\(id.pathComponent)")
    }

    func setCap(budgetID: UUID, month: String, amount: Decimal) async throws -> Decimal {
        let dto: CapDTO = try await client.send(.put, "budgets/\(budgetID.pathComponent)/cap/\(month)", body: CapBody(amount: WireFormat.money(amount)))
        guard let confirmed = WireFormat.decimal(fromMoney: dto.amount) else { throw APIError.invalidResponse }
        return confirmed
    }

    func transactions(month: String) async throws -> [Transaction] {
        let dtos: [TransactionDTO] = try await client.get("transactions", query: [URLQueryItem(name: "month", value: month)])
        return try dtos.map { try $0.toDomain() }
    }

    func createTransaction(date: Date, merchant: String, budgetID: UUID, amount: Decimal, note: String) async throws -> Transaction {
        let draft = Transaction(date: date, merchant: merchant, budgetID: budgetID, amount: amount, note: note)
        let dto: TransactionDTO = try await client.send(.post, "transactions", body: TransactionBody(draft))
        return try dto.toDomain()
    }

    func updateTransaction(_ transaction: Transaction) async throws -> Transaction {
        let dto: TransactionDTO = try await client.send(.patch, "transactions/\(transaction.id.pathComponent)", body: TransactionBody(transaction))
        return try dto.toDomain()
    }

    func deleteTransaction(id: UUID) async throws {
        try await client.delete("transactions/\(id.pathComponent)")
    }
}
