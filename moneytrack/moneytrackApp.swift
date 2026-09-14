//
//  moneytrackApp.swift
//  moneytrack
//
//  Created by Hernan's Mac on 3/8/26.
//

import SwiftUI

@main
struct moneytrackApp: App {
    @State private var store = BudgetStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}
