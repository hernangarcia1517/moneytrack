//
//  Money.swift
//  moneytrack
//
//  Decimal -> String formatting. Two decimals always, grouped thousands,
//  tabular figures. `Decimal` is used everywhere for amounts — never `Double`,
//  which drifts on money.
//

import Foundation

enum Money {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = true
        f.groupingSeparator = ","
        f.decimalSeparator = "."
        return f
    }()

    /// "$2,140.00" / "-$40.00"
    static func string(_ amount: Decimal) -> String {
        let magnitude = formatter.string(from: NSDecimalNumber(decimal: amount.magnitude)) ?? "0.00"
        return amount < 0 ? "-$\(magnitude)" : "$\(magnitude)"
    }

    /// "$860.00 left" or "-$40.00 over"
    static func remainingString(_ remaining: Decimal) -> String {
        remaining < 0 ? "\(string(remaining)) over" : "\(string(remaining)) left"
    }

    /// "$412.00 of $800.00"
    static func ofString(spent: Decimal, budgetCap: Decimal) -> String {
        "\(string(spent)) of \(string(budgetCap))"
    }

    /// Parses keypad/text-field input, accepting only digits and a single decimal point.
    static func decimal(fromInput input: String) -> Decimal {
        Decimal(string: input) ?? 0
    }
}
