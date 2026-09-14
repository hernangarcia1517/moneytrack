//
//  Budget.swift
//  moneytrack
//

import Foundation

enum BudgetGroup: String, Codable, CaseIterable, Identifiable {
    case bills = "Bills", needs = "Needs", wants = "Wants"
    var id: String { rawValue }
}

/// A user-defined monthly cap. Caps, not envelopes: each budget's cap is
/// independent of income and of every other budget — nothing is "assigned"
/// from a pool.
struct Budget: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String          // "Groceries", "Phone plan"
    var group: BudgetGroup
    var monthlyCap: Decimal
}
