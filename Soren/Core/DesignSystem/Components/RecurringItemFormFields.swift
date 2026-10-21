import SwiftUI

// MARK: - Recurring Item Form Fields

/// Shared form sections used by both SubscriptionFormView (add) and ItemEditFormView (edit).
/// Accepts explicit Bindings so neither ViewModel needs to conform to a shared protocol.
///
/// Sections included: Essentials · Classification · Dates · Note.
/// Unique sections (provider header, tier picker) remain in their respective views.
struct RecurringItemFormFields: View {
    @Binding var title: String
    @Binding var amountText: String
    @Binding var currencyCode: String
    let currencyEstimateState: CurrencyEstimateState
    @Binding var billingCycle: BillingCycle
    @Binding var category: ItemCategory
    @Binding var itemType: ItemType
    @Binding var startDate: CivilDate?
    @Binding var nextChargeDate: CivilDate?
    @Binding var autoRenew: Bool
    @Binding var endDate: CivilDate?
    @Binding var note: String
    @Binding var usageStatus: UsageStatus
    @Binding var chargeReminder: ChargeReminderOption
    @Binding var trialReminder: TrialReminderOption
    /// When `true`, a second picker for the trial-end reminder is shown.
    /// Pass `trialEndDate != nil` from the parent so the row is only visible for trial items.
    let showsTrialReminder: Bool

    var body: some View {
        essentialsSection
        classificationSection
        datesSection
        notificationsSection
        noteSection
    }

    // MARK: - Essentials

    private var essentialsSection: some View {
        Section(String(localized: "Основное")) {
            TextField(String(localized: "Название"), text: $title)

            HStack {
                TextField(String(localized: "Сумма"), text: $amountText)
                    .keyboardType(.decimalPad)

                Picker("", selection: $currencyCode) {
                    ForEach(SupportedCurrency.codes, id: \.self) { code in
                        Text(verbatim: code).tag(code)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            if currencyEstimateState.isVisible {
                CurrencyEstimateView(state: currencyEstimateState)
            }

            Picker(String(localized: "Период оплаты"), selection: $billingCycle) {
                ForEach(BillingCycle.allCases, id: \.self) { cycle in
                    Text(cycle.displayName).tag(cycle)
                }
            }
        }
    }

    // MARK: - Classification

    private var classificationSection: some View {
        Section(String(localized: "Категория")) {
            Picker(String(localized: "Категория"), selection: $category) {
                ForEach(ItemCategory.allCases, id: \.self) { cat in
                    Text(cat.displayName).tag(cat)
                }
            }

            Picker(String(localized: "Тип"), selection: $itemType) {
                ForEach(ItemType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            Picker(String(localized: "Использование"), selection: $usageStatus) {
                ForEach(UsageStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }
        }
    }

    // MARK: - Dates

    private var datesSection: some View {
        Section(String(localized: "Даты")) {
            DatePickerRow(
                label: String(localized: "Дата начала"),
                selection: $startDate
            )
            DatePickerRow(
                label: String(localized: "Дата списания"),
                selection: $nextChargeDate
            )
            Toggle(String(localized: "Автопродление"), isOn: $autoRenew)
            if !autoRenew {
                DatePickerRow(
                    label: String(localized: "Дата окончания"),
                    selection: $endDate
                )
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section(String(localized: "Уведомления")) {
            Picker(String(localized: "Напомнить о списании"), selection: $chargeReminder) {
                ForEach(ChargeReminderOption.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
            if showsTrialReminder {
                Picker(String(localized: "Напомнить об окончании пробного"), selection: $trialReminder) {
                    ForEach(TrialReminderOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
            }
        }
    }

    // MARK: - Note

    private var noteSection: some View {
        Section(String(localized: "Заметка")) {
            TextField(
                String(localized: "Тариф, аккаунт, детали..."),
                text: $note,
                axis: .vertical
            )
            .lineLimit(3...6)
        }
    }
}

// MARK: - Date Picker Row

/// A form row that displays a formatted date and opens a graphical date picker
/// in a sheet. Dismisses automatically when a different date is selected.
private struct DatePickerRow: View {
    let label: String
    @Binding var selection: CivilDate?
    @Environment(\.timeZone) private var timeZone
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack {
                Text(label)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                Text(formattedDay)
                    .foregroundStyle(.tint)
            }
        }
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                DatePicker(
                    label,
                    selection: pickerBinding,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .environment(\.calendar, pickerCalendar)
                .environment(\.timeZone, timeZone)
                .padding(.horizontal, Spacing.md)
                .onChange(of: selection) { _, _ in
                    isPresented = false
                }
                .navigationTitle(label)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Отмена")) {
                            isPresented = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "Готово")) {
                            isPresented = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var pickerCalendar: Calendar {
        var calendar = BillingCivilDay.calendar
        calendar.timeZone = timeZone
        calendar.locale = PresentationLocale.current
        return calendar
    }

    private var formattedDay: String {
        guard let selection,
              let date = try? BillingCivilDay.canonicalDate(for: selection) else { return "" }
        return (try? BillingDatePresentation.string(from: date, template: "dMMMyyyy")) ?? ""
    }

    private var pickerBinding: Binding<Date> {
        Binding {
            guard let selection, let carrier = try? BillingDatePresentation.pickerCarrier(for: selection, in: timeZone)
            else { return .now } // UI-only placeholder for invalid/empty form state; never saved.
            return carrier
        } set: { carrier in
            selection = try? BillingDatePresentation.day(fromPickerCarrier: carrier, in: timeZone)
        }
    }
}
