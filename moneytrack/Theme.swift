//
//  Theme.swift
//  moneytrack
//
//  Design tokens resolved from the Nocturne design system handoff.
//  Every color, spacing and radius value used in the app should come
//  from here — no literals in feature views.
//

import SwiftUI

enum Theme {
    enum Color {
        static let background = SwiftUI.Color(hex: 0x161826)
        static let surface = SwiftUI.Color(hex: 0x141621)          // sheets

        static let text = SwiftUI.Color(hex: 0xE9E9ED)
        static let textSecondary = SwiftUI.Color(hex: 0xC9CAD3)
        static let textMuted = SwiftUI.Color(hex: 0x9EA0AE)
        static let textFaint = SwiftUI.Color(hex: 0x6E7080)        // labels
        static let disabledInk = SwiftUI.Color(hex: 0x55576A)

        static let hairline = SwiftUI.Color(hex: 0x22242F)         // hairline / track
        static let border = SwiftUI.Color(hex: 0x2B2D3A)
        static let hoverFill = SwiftUI.Color(hex: 0x1D1F2B)

        static let accent = SwiftUI.Color(hex: 0x9184D9)
        static let accentText = SwiftUI.Color(hex: 0xB3A9E8)       // accent text on dark
        static let accentTint = SwiftUI.Color(hex: 0x2A2547)       // accent tint fill
        static let accentDeep = SwiftUI.Color(hex: 0x4B4380)       // progress dot done

        static let negative = SwiftUI.Color(hex: 0xE5707E)         // negative / overspent

        // Additional resolved values called out on individual screens in the
        // handoff (not in the core token table, but given exact hex values).
        static let rowPrimary = SwiftUI.Color(hex: 0xD9DAE1)        // budget row name
        static let emphasis = SwiftUI.Color(hex: 0xEFEFF2)          // spending merchant name
        static let accentTextOnFill = SwiftUI.Color(hex: 0xEDEBF8)  // selected chip text
    }

    enum Spacing {
        static let s4: CGFloat = 4
        static let s6: CGFloat = 6
        static let s8: CGFloat = 8
        static let s10: CGFloat = 10
        static let s12: CGFloat = 12
        static let s14: CGFloat = 14
        static let s16: CGFloat = 16
        static let s18: CGFloat = 18
        static let s20: CGFloat = 20
        static let s26: CGFloat = 26
        static let s28: CGFloat = 28

        static let gutter: CGFloat = 20
    }

    enum Radius {
        static let row: CGFloat = 6
        static let card: CGFloat = 8
        static let sheetTop: CGFloat = 20
        static let full: CGFloat = 999
    }

    enum FontSize {
        static let s52: CGFloat = 52   // headline
        static let s48: CGFloat = 48   // amount entry
        static let s26: CGFloat = 26   // budget detail title
        static let s22: CGFloat = 22   // stat values
        static let s17: CGFloat = 17   // month label, group name
        static let s15: CGFloat = 15   // body
        static let s14: CGFloat = 14   // empty state
        static let s13: CGFloat = 13   // secondary body
        static let s12: CGFloat = 12   // captions
        static let s11: CGFloat = 11   // uppercase labels
        static let s10: CGFloat = 10   // tab bar labels
        static let s8: CGFloat = 8     // day numbers
    }
}

extension SwiftUI.Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

/// The fading-at-the-ends hairline used beneath the Plan headline and the
/// Spending daily chart — a 1pt rule that fades in/out over 48pt at each end.
/// A design-system signature; reproduce exactly rather than using a plain divider.
struct FadingRule: View {
    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let fade = min(48 / width, 0.5)
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Theme.Color.hairline, location: fade),
                    .init(color: Theme.Color.hairline, location: 1 - fade),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .frame(height: 1)
    }
}
