//
//  LoadStatusView.swift
//  moneytrack
//
//  Shown under the month header in place of a screen's content while the
//  viewed month is loading, or when loading failed.
//

import SwiftUI

struct LoadStatusView: View {
    @Environment(BudgetStore.self) private var store

    var body: some View {
        switch store.status {
        case .loaded:
            EmptyView()
        case .loading:
            ProgressView()
                .tint(Theme.Color.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 120)
        case .failed(let message):
            VStack(spacing: Theme.Spacing.s14) {
                Text(message)
                    .font(.system(size: Theme.FontSize.s14))
                    .foregroundStyle(Theme.Color.textMuted)
                    .multilineTextAlignment(.center)
                Button {
                    store.retry()
                } label: {
                    Text("Retry")
                        .font(.system(size: Theme.FontSize.s15))
                        .foregroundStyle(Theme.Color.accent)
                        .padding(.horizontal, Theme.Spacing.s20)
                        .padding(.vertical, 10)
                        .overlay(Capsule().strokeBorder(Theme.Color.accent, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.vertical, 100)
            .frame(maxWidth: .infinity)
        }
    }
}
