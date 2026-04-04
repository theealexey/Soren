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
    @Binding var billingCycle: BillingCycle
    @Binding var category: ItemCategory
    @Binding var itemType: ItemType
    @Binding var startDate: Date
    @Binding var nextChargeDate: Date
    @Binding var note: String

    var body: some View {
        essentialsSection
        classificationSection
        datesSection
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
        }
    }

    // MARK: - Dates

    private var datesSection: some View {
        Section(String(localized: "Даты")) {
            DatePicker(
                String(localized: "Дата начала"),
                selection: $startDate,
                displayedComponents: .date
            )

            DatePicker(
                String(localized: "Следующее списание"),
                selection: $nextChargeDate,
                displayedComponents: .date
            )
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
