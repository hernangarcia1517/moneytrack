//
//  ContentView.swift
//  moneytrack
//
//  App shell: a custom two-item bottom bar (Plan / Spending) with a centre
//  "+" action that presents AddTransactionView full-screen. The centre item
//  is deliberately not a real tab — it must never change selection.
//

import SwiftUI

enum AppTab {
    case plan, spending
}

struct ContentView: View {
    @Environment(BudgetStore.self) private var store
    @State private var selectedTab: AppTab = .plan
    @State private var isAddingTransaction = false
    @State private var groupToExpand: BudgetGroup?

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Color.background.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .plan:
                    PlanView(groupToExpand: $groupToExpand)
                case .spending:
                    SpendingView()
                }
            }
            .padding(.bottom, 83)

            VStack(spacing: 0) {
                Spacer()
                bottomBar
            }
        }
        .fullScreenCover(isPresented: $isAddingTransaction) {
            AddTransactionView { budgetID in
                isAddingTransaction = false
                selectedTab = .plan
                if let group = store.budget(for: budgetID)?.group {
                    groupToExpand = group
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            tabItem(tab: .plan, title: "Plan", systemImage: "chart.bar.fill")
                .frame(width: 64)

            Spacer()

            Button {
                isAddingTransaction = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Theme.Color.accent)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle().strokeBorder(Theme.Color.accent, lineWidth: 1)
                    )
            }
            .offset(y: -4)

            Spacer()

            tabItem(tab: .spending, title: "Spending", systemImage: "banknote")
                .frame(width: 64)
        }
        .padding(.horizontal, Theme.Spacing.s20)
        .frame(height: 83, alignment: .top)
        .padding(.top, 1)
        .background(
            Theme.Color.background
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.Color.hairline).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabItem(tab: AppTab, title: String, systemImage: String) -> some View {
        let isActive = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(.system(size: Theme.FontSize.s10))
            }
            .foregroundStyle(isActive ? Theme.Color.accent : Theme.Color.textFaint)
        }
        .buttonStyle(.plain)
    }
}

extension AppTab: Equatable {}

/// The month header shared by the Plan and Spending screen roots: the
/// (currently inert) month label and "through the Nth" marker. It lives at
/// the top of each tab's own NavigationStack so it disappears, as intended,
/// when a screen is pushed on top (e.g. BudgetDetailView).
struct MonthHeader: View {
    @Environment(BudgetStore.self) private var store

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 4) {
                Text(monthLabel)
                    .font(.system(size: Theme.FontSize.s17, weight: .medium))
                    .foregroundStyle(Theme.Color.text)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Color.text)
                    .frame(width: 11, height: 7)
            }

            Spacer()

            Text(throughLabel)
                .font(.system(size: Theme.FontSize.s12))
                .foregroundStyle(Theme.Color.textMuted)
        }
        .padding(.horizontal, Theme.Spacing.s20)
        .padding(.bottom, Theme.Spacing.s12)
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.calendar = .gregorian
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: store.currentMonth.start)
    }

    private var throughLabel: String {
        "through the \(store.elapsedDayOfMonth.withOrdinalSuffix)"
    }
}

extension Int {
    var withOrdinalSuffix: String {
        let suffix: String
        switch (self % 100, self % 10) {
        case (11, _), (12, _), (13, _): suffix = "th"
        case (_, 1): suffix = "st"
        case (_, 2): suffix = "nd"
        case (_, 3): suffix = "rd"
        default: suffix = "th"
        }
        return "\(self)\(suffix)"
    }
}

#Preview {
    ContentView()
        .environment(BudgetStore())
}
