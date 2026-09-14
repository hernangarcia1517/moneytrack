//
//  AmountKeypad.swift
//  moneytrack
//
//  The 3-column custom keypad used on Add step 1.
//

import SwiftUI

private enum KeypadKey: Hashable, Identifiable {
    case digit(String)
    case decimal
    case backspace

    var id: String {
        switch self {
        case .digit(let d): return d
        case .decimal: return "."
        case .backspace: return "back"
        }
    }
}

struct AmountKeypad: View {
    var onDigit: (String) -> Void
    var onDecimal: () -> Void
    var onBackspace: () -> Void

    private let rows: [[KeypadKey]] = [
        [.digit("1"), .digit("2"), .digit("3")],
        [.digit("4"), .digit("5"), .digit("6")],
        [.digit("7"), .digit("8"), .digit("9")],
        [.decimal, .digit("0"), .backspace],
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 10) {
                    ForEach(rows[r]) { key in
                        keyButton(key)
                    }
                }
            }
        }
    }

    private func keyButton(_ key: KeypadKey) -> some View {
        Button {
            switch key {
            case .digit(let d): onDigit(d)
            case .decimal: onDecimal()
            case .backspace: onBackspace()
            }
        } label: {
            keyLabel(key)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
        }
        .buttonStyle(KeypadButtonStyle())
    }

    @ViewBuilder
    private func keyLabel(_ key: KeypadKey) -> some View {
        switch key {
        case .digit(let d):
            Text(d).font(.system(size: 22)).foregroundStyle(Theme.Color.text)
        case .decimal:
            Text(".").font(.system(size: 22)).foregroundStyle(Theme.Color.text)
        case .backspace:
            Image(systemName: "delete.left")
                .font(.system(size: 20))
                .foregroundStyle(Theme.Color.text)
        }
    }
}

private struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Theme.Color.hairline : Theme.Color.hoverFill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}
