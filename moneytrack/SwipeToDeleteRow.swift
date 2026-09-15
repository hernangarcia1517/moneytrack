//
//  SwipeToDeleteRow.swift
//  moneytrack
//
//  A row that reveals a fixed-width red "Delete" action when swiped left,
//  firing immediately on tap — no confirmation (a deliberate product
//  decision for this design pass; may be revisited later). Coordinates
//  with sibling rows via `openID` so only one row is ever swiped open at a
//  time on a given screen.
//
//  This owns the row's tap gesture itself rather than nesting a
//  Button/NavigationLink inside the draggable content — with no other
//  gesture recognizer competing for the same touch, there's no ambiguity
//  between "this is a drag" and "this is a tap" for SwiftUI to resolve.
//  Callers that previously used NavigationLink(value:) for row taps need an
//  explicit `NavigationStack(path:)` instead; see PlanView.
//

import SwiftUI

struct SwipeToDeleteRow<ID: Hashable, Content: View>: View {
    let id: ID
    @Binding var openID: ID?
    var cornerRadius: CGFloat = 0
    var onTap: () -> Void = {}
    var onDelete: () -> Void
    @ViewBuilder var content: () -> Content

    private let deleteWidth: CGFloat = 92

    @State private var dragTranslation: CGFloat = 0

    private var isOpen: Bool { openID == id }
    private var restingOffset: CGFloat { isOpen ? -deleteWidth : 0 }
    private var liveOffset: CGFloat {
        max(-deleteWidth, min(0, restingOffset + dragTranslation))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: performDelete) {
                Text("Delete")
                    .font(.system(size: Theme.FontSize.s14))
                    .foregroundStyle(Theme.Color.negativeText)
                    .frame(width: deleteWidth)
                    .frame(maxHeight: .infinity)
                    .background(Theme.Color.negative)
            }
            .buttonStyle(.plain)

            content()
                .frame(maxWidth: .infinity)
                .background(Theme.Color.background)
                .contentShape(Rectangle())
                .offset(x: liveOffset)
                .animation(.easeInOut(duration: 0.18), value: openID)
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            dragTranslation = value.translation.width
                        }
                        .onEnded { value in
                            let projected = restingOffset + value.translation.width
                            openID = projected < -deleteWidth / 2 ? id : nil
                            dragTranslation = 0
                        }
                )
                .onTapGesture {
                    if isOpen {
                        openID = nil
                    } else {
                        onTap()
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private func performDelete() {
        openID = nil
        onDelete()
    }
}
