//
//  MonthPickerSheet.swift
//  moneytrack
//
//  Presented from MonthHeader's chevron. A year stepper (bounded to 2 years
//  back / 1 year forward from the app's fixed "today", BudgetStore.
//  referenceDate) plus a 12-month grid for the selected year. Tapping a
//  month sets BudgetStore.viewedMonth and dismisses.
//

import SwiftUI

struct MonthPickerSheet: View {
    @Environment(BudgetStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var pickerYear: Int

    init(initialYear: Int) {
        _pickerYear = State(initialValue: initialYear)
    }

    private static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]

    private var todayYear: Int { Calendar.gregorian.component(.year, from: BudgetStore.referenceDate) }
    private var minYear: Int { todayYear - 2 }
    private var maxYear: Int { todayYear + 1 }

    var body: some View {
        VStack(spacing: 0) {
            header
            monthList
        }
        .background(
            Theme.Color.surface
                .clipShape(.rect(topLeadingRadius: Theme.Radius.sheetTop, topTrailingRadius: Theme.Radius.sheetTop))
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.Color.border).frame(height: 1)
                }
                .ignoresSafeArea()
        )
        .presentationDetents([.fraction(0.74)])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Month")
                        .font(.system(size: Theme.FontSize.s15, weight: .medium))
                }
                .foregroundStyle(Theme.Color.neutral300)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 2) {
                yearStepButton(systemImage: "chevron.left", enabled: pickerYear > minYear) {
                    pickerYear = max(minYear, pickerYear - 1)
                }

                Text(String(pickerYear))
                    .font(.system(size: Theme.FontSize.s14))
                    .foregroundStyle(Theme.Color.neutral200)
                    .monospacedDigit()
                    .frame(minWidth: 46)

                yearStepButton(systemImage: "chevron.right", enabled: pickerYear < maxYear) {
                    pickerYear = min(maxYear, pickerYear + 1)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.gutter)
        .padding(.top, Theme.Spacing.s18)
        .padding(.bottom, Theme.Spacing.s10)
    }

    private func yearStepButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Theme.Color.neutral200 : Theme.Color.neutral700)
        .disabled(!enabled)
    }

    // MARK: - Month list

    private var monthList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<12, id: \.self) { index in
                    monthRow(monthIndex: index)
                }
            }
            .padding(.horizontal, Theme.Spacing.s12)
        }
        .padding(.bottom, Theme.Spacing.s26)
    }

    private func monthRow(monthIndex: Int) -> some View {
        let date = Calendar.gregorian.date(from: DateComponents(year: pickerYear, month: monthIndex + 1, day: 1))!
        let isViewed = Calendar.gregorian.isDate(date, equalTo: store.viewedMonth, toGranularity: .month)
        let isRealToday = Calendar.gregorian.isDate(date, equalTo: BudgetStore.referenceDate, toGranularity: .month)
        let isAhead = !isRealToday && date > BudgetStore.referenceDate

        return Button {
            store.setViewedMonth(date)
            dismiss()
        } label: {
            HStack {
                Text(Self.monthNames[monthIndex])
                    .font(.system(size: Theme.FontSize.s15))
                Spacer()
                Text(isRealToday ? "THIS MONTH" : isAhead ? "AHEAD" : "")
                    .font(.system(size: Theme.FontSize.s11))
                    .tracking(0.5)
                    .foregroundStyle(Theme.Color.neutral500)
            }
            .foregroundStyle(rowTint(isViewed: isViewed, isRealToday: isRealToday))
            .padding(.vertical, Theme.Spacing.s12 + 1)
            .padding(.horizontal, Theme.Spacing.s12)
            .background(isViewed ? Theme.Color.neutral800 : .clear)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.row))
        }
        .buttonStyle(.plain)
    }

    private func rowTint(isViewed: Bool, isRealToday: Bool) -> Color {
        if isViewed { return Theme.Color.accent200 }
        if isRealToday { return Theme.Color.text }
        return Theme.Color.neutral300
    }
}
