//
//  SignInView.swift
//  moneytrack
//
//  Sign-in screen (issue #7). Layout only: the button does nothing until the
//  Apple Developer enrollment (#6) and server token exchange (#1) are done.
//  Not yet shown by the app; ContentView still opens straight to the tabs.
//

import AuthenticationServices
import SwiftUI

struct SignInView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.s12) {
            Spacer()
            Text("moneytrack")
                .font(.system(size: Theme.FontSize.s32, weight: .semibold))
                .foregroundStyle(Theme.Color.text)
            Text("Sign in to see your budgets")
                .font(.system(size: Theme.FontSize.s15))
                .foregroundStyle(Theme.Color.textMuted)
            Spacer()
            // shortcut: no-op, disabled; wire to the Apple request/completion once #6 and server #1 land.
            SignInWithAppleButton(.signIn, onRequest: { _ in }, onCompletion: { _ in })
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .disabled(true)
            Text("Sign in is not available yet")
                .font(.system(size: Theme.FontSize.s12))
                .foregroundStyle(Theme.Color.textFaint)
        }
        .padding(.horizontal, Theme.Spacing.gutter)
        .padding(.bottom, Theme.Spacing.s28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Color.background.ignoresSafeArea())
    }
}

#Preview {
    SignInView().preferredColorScheme(.dark)
}
