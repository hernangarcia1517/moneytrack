import Foundation

nonisolated struct ErrorBodyDTO: Decodable {
    var error: String?
    var message: String?
}

nonisolated struct BudgetDTO: Decodable {
    var id: UUID
    var name: String
    var budgetGroup: BudgetGroup
    var cap: String?
}

nonisolated struct CreateBudgetBody: Encodable {
    var name: String
    var budgetGroup: BudgetGroup
    var cap: String
    var month: String
}

nonisolated struct UpdateBudgetBody: Encodable {
    var name: String?
    var budgetGroup: BudgetGroup?
}

nonisolated struct CapBody: Encodable {
    var amount: String
}

nonisolated struct CapDTO: Decodable {
    var budgetId: UUID
    var month: String
    var amount: String
}

nonisolated struct TransactionDTO: Decodable {
    var id: UUID
    var budgetId: UUID
    var date: String
    var merchant: String
    var amount: String
    var note: String
}

nonisolated struct TransactionBody: Encodable {
    var budgetId: UUID
    var date: String
    var merchant: String
    var amount: String
    var note: String
}

// MARK: - Wire formats

nonisolated enum WireFormat {
    private static let posix = Locale(identifier: "en_US_POSIX")
    private static let moneyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = posix
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// "2026-10-31", from explicit calendar components (not a DateFormatter, which a
    /// non-Gregorian device calendar or locale can change).
    static func day(_ date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld-%02ld-%02ld", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Local start of the given "YYYY-MM-DD" day.
    static func date(fromDay string: String, calendar: Calendar = Calendar(identifier: .gregorian)) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, string.count == 10 else { return nil }
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = calendar.date(from: components),
              calendar.dateComponents([.year, .month, .day], from: date) == components
        else { return nil }
        return date
    }

    /// Always two decimals ("42.10"); `Decimal` alone prints "42.1".
    static func money(_ amount: Decimal) -> String {
        moneyFormatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0.00"
    }

    static func decimal(fromMoney string: String) -> Decimal? {
        Decimal(string: string, locale: posix)
    }
}

// MARK: - Mapping

nonisolated extension BudgetDTO {
    func budget() -> Budget {
        Budget(id: id, name: name, group: budgetGroup)
    }

    func withCap() throws -> BudgetWithCap {
        guard let cap, let amount = WireFormat.decimal(fromMoney: cap) else { throw APIError.invalidResponse }
        return BudgetWithCap(budget: budget(), cap: amount)
    }
}

nonisolated extension TransactionDTO {
    func toDomain() throws -> Transaction {
        guard let date = WireFormat.date(fromDay: date), let amount = WireFormat.decimal(fromMoney: amount) else {
            throw APIError.invalidResponse
        }
        return Transaction(id: id, date: date, merchant: merchant, budgetID: budgetId, amount: amount, note: note)
    }
}

nonisolated extension TransactionBody {
    init(_ transaction: Transaction) {
        self.init(
            budgetId: transaction.budgetID,
            date: WireFormat.day(transaction.date),
            merchant: transaction.merchant,
            amount: WireFormat.money(transaction.amount),
            note: transaction.note
        )
    }
}
