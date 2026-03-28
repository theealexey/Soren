import Foundation

// MARK: - Use Case: Update Recurring Item

/// Validates and persists changes to an existing recurring item.
@MainActor
struct UpdateRecurringItem {

    private let repository: any RecurringItemRepository

    init(repository: any RecurringItemRepository) {
        self.repository = repository
    }

    func execute(_ item: RecurringItem) throws {
        try validate(item)
        var updated = item
        updated.updatedAt = .now
        try repository.update(updated)
    }

    // MARK: - Validation

    private func validate(_ item: RecurringItem) throws {
        let trimmedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            throw ValidationError.emptyTitle
        }
        if item.amount <= 0 {
            throw ValidationError.invalidAmount
        }
    }
}

// MARK: - Validation Error

extension UpdateRecurringItem {
    enum ValidationError: LocalizedError {
        case emptyTitle
        case invalidAmount

        var errorDescription: String? {
            switch self {
            case .emptyTitle:    "Укажите название подписки"
            case .invalidAmount: "Сумма должна быть больше нуля"
            }
        }
    }
}
