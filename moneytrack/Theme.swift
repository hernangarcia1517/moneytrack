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
    // Corrected 2026-09-14: every token below was re-derived from the V2
    // design source. `MoneyTrack Prototype.dc.html`'s own `<head>` declares
    // a `:root` block *after* its `<link>` to the Nocturne stylesheet,
    // overriding `--color-bg`/`--color-surface`/`--color-section`/the full
    // `--color-neutral-*` and `--color-accent-*` ramps with a cooler,
    // true-gray/blue palette — CSS gives a later same-specificity `:root`
    // rule priority, so this override (not Nocturne's own base tokens) is
    // what actually renders, confirmed against real screenshots of the
    // prototype open in a browser. An earlier pass here (Phase 4) read
    // only the linked Nocturne stylesheet and wrongly dismissed this
    // override block as unrelated "design-tool editor chrome" — it isn't;
    // it's the actual V2 color update. `--color-text` and everything else
    // Nocturne defines outside that override list (radii, fonts, shadows)
    // are untouched, so they keep their original values below.
    //
    // The app's own semantic token *names* (background, accent, hairline,
    // etc.) are unchanged so no call site elsewhere needs editing — only
    // their resolved hex values move to the corrected ramp. Where a name
    // doesn't map to a literal `--color-bg`/`--color-text`/etc. variable
    // (hairline, border, hoverFill, accentText, accentTint, accentDeep,
    // accentTextOnFill, rowPrimary, emphasis — all "additional resolved
    // values" hand-picked for specific screens, not raw CSS vars), each was
    // re-mapped to the nearest step of the *old* ramp it was originally
    // drawn from, then swapped for that same step in the *new* ramp — e.g.
    // old `accentTint` (#2A2547) sat almost exactly on old `accent-900`
    // (#2B2741), so it now takes new `accent-900` (#1F2D3B).
    enum Color {
        static let background = SwiftUI.Color(hex: 0x26262A)
        static let surface = SwiftUI.Color(hex: 0x2F2F35)          // sheets

        static let text = SwiftUI.Color(hex: 0xE9E9ED)             // unchanged — not part of the override
        static let textSecondary = SwiftUI.Color(hex: 0xC2C2C8)    // was nearest old neutral-300, now new neutral-300
        static let textMuted = SwiftUI.Color(hex: 0x74747D)        // was nearest old neutral-500, now new neutral-500
        static let textFaint = SwiftUI.Color(hex: 0x5A5A62)        // labels — was nearest old neutral-600, now new neutral-600
        static let disabledInk = SwiftUI.Color(hex: 0x43434A)      // was nearest old neutral-700, now new neutral-700

        static let hairline = SwiftUI.Color(hex: 0x2B2B30)         // hairline / track — nearest old neutral-900, now new neutral-900
        static let border = SwiftUI.Color(hex: 0x35353B)           // nearest old neutral-800, now new neutral-800
        static let hoverFill = SwiftUI.Color(hex: 0x2B2B30)        // nearest old neutral-900, now new neutral-900

        static let accent = SwiftUI.Color(hex: 0x5C92D6)
        static let accentText = SwiftUI.Color(hex: 0x7AA8DE)       // accent text on dark — was nearest old accent-400, now new accent-400
        static let accentTint = SwiftUI.Color(hex: 0x1F2D3B)       // accent tint fill — was nearest old accent-900, now new accent-900
        static let accentDeep = SwiftUI.Color(hex: 0x293F56)       // progress dot done — was nearest old accent-800, now new accent-800

        static let negative = SwiftUI.Color(hex: 0xE5707E)         // negative / overspent — a fixed literal in the prototype's own JS (`const RED = '#e5707e'`), not ramp-derived; unchanged in V2
        static let negativeText = SwiftUI.Color(hex: 0x241416)     // text on the negative fill (e.g. swipe-to-delete) — also a fixed literal, unchanged

        // Additional resolved values called out on individual screens in the
        // handoff (not in the core token table, but given exact hex values).
        static let rowPrimary = SwiftUI.Color(hex: 0xD6D6DA)        // budget row name — was nearest old neutral-200, now new neutral-200
        static let emphasis = SwiftUI.Color(hex: 0xE8E8EA)          // spending merchant name — was nearest old neutral-100, now new neutral-100
        static let accentTextOnFill = SwiftUI.Color(hex: 0xC2D9F2)  // selected chip text — was nearest old accent-200, now new accent-200

        // The numbered neutral/accent ramp from the Nocturne design system,
        // as overridden by the V2 prototype (see the correction note
        // above) — resolved directly from `MoneyTrack Prototype.dc.html`'s
        // own inline `<style>` block, the actual winning values per CSS
        // cascade. Newer (V2 design pass) screens pull arbitrary steps from
        // this ramp rather than a small set of pre-named roles; add more of
        // the ramp here as later phases need it.
        static let neutral100 = SwiftUI.Color(hex: 0xE8E8EA)
        static let neutral200 = SwiftUI.Color(hex: 0xD6D6DA)
        static let neutral300 = SwiftUI.Color(hex: 0xC2C2C8)
        static let neutral400 = SwiftUI.Color(hex: 0x9A9AA2)
        static let neutral500 = SwiftUI.Color(hex: 0x74747D)
        static let neutral600 = SwiftUI.Color(hex: 0x5A5A62)
        static let neutral700 = SwiftUI.Color(hex: 0x43434A)
        static let neutral800 = SwiftUI.Color(hex: 0x35353B)
        static let neutral900 = SwiftUI.Color(hex: 0x2B2B30)
        static let accent200 = SwiftUI.Color(hex: 0xC2D9F2)
        static let accent700 = SwiftUI.Color(hex: 0x33587F)
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
        static let s32: CGFloat = 32   // Spending scrub headline
        static let s30: CGFloat = 30   // Monthly budgets total
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
