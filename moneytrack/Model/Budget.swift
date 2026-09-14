//
//  Budget.swift
//  moneytrack
//

import Foundation

enum BudgetGroup: String, Codable, CaseIterable, Identifiable {
    case bills = "Bills", needs = "Needs", wants = "Wants"
    var id: String { rawValue }
}

/// A user-defined monthly budget cap. Caps, not envelopes: each budget's cap
/// is independent of income and of every other budget — nothing is
/// "assigned" from a pool.
///
/// Budget caps are self-contained per month: `monthlyBudgetCap` is the
/// base/default cap used for any month that has no explicit override, and
/// `budgetCapOverrides` holds per-month values keyed by
/// `Budget.monthKey(for:)`. Editing the budget cap for one month never
/// touches another month's value — see `BudgetStore.budgetCap(_:in:)` /
/// `setBudgetCap(_:to:in:)`, which are the only things that should read or
/// write these directly.
struct Budget: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String          // "Groceries", "Phone plan"
    var group: BudgetGroup
    var monthlyBudgetCap: Decimal
    var budgetCapOverrides: [String: Decimal] = [:]

    /// On-disk JSON key names are kept stable across the `cap` ->
    /// `budgetCap` rename so already-persisted data doesn't need a schema
    /// migration.
    enum CodingKeys: String, CodingKey {
        case id, name, group
        case monthlyBudgetCap = "monthlyCap"
        case budgetCapOverrides = "capOverrides"
    }

    init(id: UUID = UUID(), name: String, group: BudgetGroup, monthlyBudgetCap: Decimal, budgetCapOverrides: [String: Decimal] = [:]) {
        self.id = id
        self.name = name
        self.group = group
        self.monthlyBudgetCap = monthlyBudgetCap
        self.budgetCapOverrides = budgetCapOverrides
    }

    /// Custom decode so that JSON persisted before `budgetCapOverrides`
    /// existed (missing the key entirely) still loads instead of failing
    /// and silently falling back to reseeded data — synthesized `Decodable`
    /// does not fall back to a property's default for a missing key, it
    /// throws.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        group = try container.decode(BudgetGroup.self, forKey: .group)
        monthlyBudgetCap = try container.decode(Decimal.self, forKey: .monthlyBudgetCap)
        budgetCapOverrides = try container.decodeIfPresent([String: Decimal].self, forKey: .budgetCapOverrides) ?? [:]
    }

    /// "2026-03" key identifying a calendar month, independent of day —
    /// the dictionary key used by `budgetCapOverrides`.
    static func monthKey(for date: Date, calendar: Calendar = .gregorian) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }
}
