//
//  Budget.swift
//  moneytrack
//

import Foundation

enum BudgetGroup: String, Codable, CaseIterable, Identifiable {
    case bills = "Bills", needs = "Needs", wants = "Wants"
    var id: String { rawValue }
}

/// A user-defined monthly budget. Caps, not envelopes: each budget's cap is
/// independent of income and of every other budget. The cap itself is not
/// stored here — it varies by month and lives in `BudgetStore`
/// (`budgetCap(_:in:)`), as returned by the server.
struct Budget: Identifiable, Hashable {
    var id = UUID()
    var name: String          // "Groceries", "Phone plan"
    var group: BudgetGroup

    /// "2026-03" key identifying a calendar month, independent of day —
    /// the key the server API and the store's per-month caches use.
    static func monthKey(for date: Date, calendar: Calendar = .gregorian) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }
}
