import Foundation

// MARK: - Use Case: Save Recurring Item

/// Validates and persists a new recurring item.
@MainActor
struct SaveRecurringItem {

    private let repository: any RecurringItemRepository

    init(repository: any RecurringItemRepository) {
        self.repository = repository
    }

    func execute(_ item: RecurringItem) throws {
        try validate(item)
        try repository.save(item)
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

extension SaveRecurringItem {
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
