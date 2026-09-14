//
//  Transaction.swift
//  moneytrack
//

import Foundation

/// A single spend. Amounts are always positive — there is no income or
/// transfer type; this app only tracks spending against caps.
struct Transaction: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var merchant: String
    var budgetID: Budget.ID
    var amount: Decimal       // always positive
    var note: String = ""
}
