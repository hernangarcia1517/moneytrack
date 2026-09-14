//
//  SeedData.swift
//  moneytrack
//
//  Mock data from the design handoff, used verbatim to seed a fresh store.
//  On-track scenario: March 2026 through the 16th, headline $3,307.00.
//

import Foundation

extension BudgetStore {
    static func seedData() -> (budgets: [Budget], transactions: [Transaction]) {
        func day(_ day: Int) -> Date {
            Calendar.gregorian.date(from: DateComponents(year: 2026, month: 3, day: day))!
        }

        let rent = Budget(name: "Rent", group: .bills, monthlyBudgetCap: 2000)
        let electricity = Budget(name: "Electricity", group: .bills, monthlyBudgetCap: 100)
        let sewer = Budget(name: "Sewer", group: .bills, monthlyBudgetCap: 100)
        let studentLoans = Budget(name: "Student loans", group: .bills, monthlyBudgetCap: 500)
        let groceries = Budget(name: "Groceries", group: .needs, monthlyBudgetCap: 800)
        let eatingOut = Budget(name: "Eating out", group: .wants, monthlyBudgetCap: 200)
        let nightsOut = Budget(name: "Nights out", group: .wants, monthlyBudgetCap: 200)

        let budgets = [rent, electricity, sewer, studentLoans, groceries, eatingOut, nightsOut]

        let transactions = [
            Transaction(date: day(1), merchant: "Sterling Court Apts", budgetID: rent.id, amount: 2000),
            Transaction(date: day(2), merchant: "Trader Joe's", budgetID: groceries.id, amount: 96.40),
            Transaction(date: day(3), merchant: "City Power", budgetID: electricity.id, amount: 92),
            Transaction(date: day(3), merchant: "Metro Water & Sewer", budgetID: sewer.id, amount: 100),
            Transaction(date: day(4), merchant: "Pho Bistro", budgetID: eatingOut.id, amount: 34.20),
            Transaction(date: day(5), merchant: "Nelnet", budgetID: studentLoans.id, amount: 500),
            Transaction(date: day(6), merchant: "Safeway", budgetID: groceries.id, amount: 132.18),
            Transaction(date: day(7), merchant: "The Lantern Bar", budgetID: nightsOut.id, amount: 48),
            Transaction(date: day(8), merchant: "Taqueria Luna", budgetID: eatingOut.id, amount: 21.75),
            Transaction(date: day(9), merchant: "Trader Joe's", budgetID: groceries.id, amount: 74.05),
            Transaction(date: day(11), merchant: "Sushi Kaze", budgetID: eatingOut.id, amount: 62.05),
            Transaction(date: day(12), merchant: "Costco", budgetID: groceries.id, amount: 109.37),
            Transaction(date: day(14), merchant: "Pins & Pitchers", budgetID: nightsOut.id, amount: 37),
        ]

        return (budgets, transactions)
    }
}
