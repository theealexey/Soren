#if DEBUG
import SwiftUI

struct NotificationDiagnosticsView: View {
    private let provider: NotificationDiagnosticsProvider
    @State private var snapshot: NotificationDiagnosticsSnapshot?
    @State private var isLoading = false

    init(provider: NotificationDiagnosticsProvider) {
        self.provider = provider
    }

    var body: some View {
        List {
            if let snapshot {
                authorizationSection(snapshot)
                reconciliationSection(snapshot.latestReconciliation)
                pendingSection(snapshot.pending)
                deliveredSection(snapshot.delivered)
            } else if isLoading {
                ProgressView(String(localized: "Загрузка диагностики уведомлений"))
            }
        }
        .navigationTitle(String(localized: "Диагностика"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isLoading {
                    ProgressView()
                        .accessibilityLabel(String(localized: "Обновить снимок"))
                } else {
                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel(String(localized: "Обновить снимок"))
                }
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func authorizationSection(_ snapshot: NotificationDiagnosticsSnapshot) -> some View {
        Section(String(localized: "Авторизация")) {
            diagnosticRow(
                String(localized: "Статус"),
                value: Self.authorizationText(snapshot.authorizationStatus)
            )
            diagnosticRow(
                String(localized: "Время снимка"),
                value: snapshot.capturedAt.formatted(date: .abbreviated, time: .standard)
            )
        }
    }

    @ViewBuilder
    private func reconciliationSection(_ record: NotificationReconciliationRecord?) -> some View {
        Section(String(localized: "Последняя синхронизация")) {
            if let record {
                diagnosticRow(String(localized: "Источник"), value: sourceText(record.source))
                diagnosticRow(String(localized: "Начато"), value: record.startedAt.formatted(date: .abbreviated, time: .standard))
                diagnosticRow(String(localized: "Завершено"), value: record.completedAt.formatted(date: .abbreviated, time: .standard))
                diagnosticRow(String(localized: "Запланировано"), value: String(record.desiredCount))
                diagnosticRow(String(localized: "Удалено из ожидающих"), value: String(record.removedPendingCount))
                diagnosticRow(String(localized: "Удалено из доставленных"), value: String(record.removedDeliveredCount))
                diagnosticRow(String(localized: "Добавлено"), value: String(record.addedCount))
                diagnosticRow(String(localized: "Не удалось добавить"), value: String(record.failedAddCount))
                diagnosticRow(String(localized: "Ошибки планирования"), value: String(record.planningFailureCount))
                diagnosticRow(
                    String(localized: "Итоговая авторизация"),
                    value: Self.authorizationText(record.authorizationStatus)
                )
                diagnosticRow(
                    String(localized: "Категория ошибки"),
                    value: Self.failureText(record.failureCategory)
                )
            } else {
                Text(String(localized: "Нет данных о синхронизации"))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func pendingSection(_ requests: [NotificationDiagnosticPendingItem]) -> some View {
        Section("\(String(localized: "Ожидающие уведомления")) (\(requests.count))") {
            if requests.isEmpty {
                Text(String(localized: "Нет ожидающих уведомлений"))
                    .foregroundStyle(.secondary)
            }
            ForEach(requests, id: \.identifier) { request in
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.identifier)
                        .font(.caption.monospaced())
                    diagnosticMetadata(request.identity)
                    diagnosticRow(String(localized: "Тип триггера"), value: triggerText(request.triggerKind))
                    diagnosticRow(
                        String(localized: "Повторяется"),
                        value: request.repeats.map { $0 ? String(localized: "Да") : String(localized: "Нет") }
                            ?? String(localized: "Недоступно")
                    )
                    diagnosticRow(
                        String(localized: "Время срабатывания"),
                        value: request.fireDate?.formatted(date: .abbreviated, time: .shortened)
                            ?? String(localized: "Недоступно")
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func deliveredSection(_ requests: [NotificationDiagnosticDeliveredItem]) -> some View {
        Section("\(String(localized: "Доставленные уведомления")) (\(requests.count))") {
            if requests.isEmpty {
                Text(String(localized: "Нет доставленных уведомлений"))
                    .foregroundStyle(.secondary)
            }
            ForEach(requests, id: \.identifier) { request in
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.identifier)
                        .font(.caption.monospaced())
                    diagnosticMetadata(request.identity)
                    diagnosticRow(
                        String(localized: "Дата доставки"),
                        value: request.deliveredDate.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func diagnosticMetadata(_ identity: NotificationDiagnosticRequestIdentity) -> some View {
        diagnosticRow(String(localized: "Тип"), value: kindText(identity.kind))
        diagnosticRow(String(localized: "Элемент"), value: identity.itemSuffix ?? String(localized: "Недоступно"))
        diagnosticRow(String(localized: "Дата события"), value: identity.occurrenceLocalDate ?? String(localized: "Недоступно"))
        diagnosticRow(
            String(localized: "Смещение"),
            value: identity.offsetDays.map(String.init) ?? String(localized: "Недоступно")
        )
    }

    private func diagnosticRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
            Spacer(minLength: 16)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .font(Typography.caption)
    }

    private func load() async {
        isLoading = true
        if case .loaded(let value) = await provider.loadSnapshot() {
            snapshot = value
        }
        isLoading = false
    }

    static func authorizationText(_ status: NotificationAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: String(localized: "Уведомления не включены")
        case .denied: String(localized: "Отключены в настройках iOS")
        case .authorized: String(localized: "Включены")
        case .provisional: String(localized: "Включены тихо")
        case .ephemeral: String(localized: "Временно включены")
        case .unknown: String(localized: "Статус недоступен")
        }
    }

    static func failureText(_ category: NotificationReconciliationFailureCategory?) -> String {
        switch category {
        case .add: String(localized: "Ошибка добавления")
        case .planning: String(localized: "Ошибка планирования")
        case .planningAndAdd: String(localized: "Ошибки планирования и добавления")
        case .repository: String(localized: "Ошибка загрузки данных")
        case nil: String(localized: "Нет ошибок")
        }
    }

    private func sourceText(_ source: NotificationReconciliationSource) -> String {
        switch source {
        case .foreground: String(localized: "Возврат в приложение")
        case .create: String(localized: "Создание подписки")
        case .update: String(localized: "Изменение подписки")
        case .delete: String(localized: "Удаление подписки")
        case .permissionGrant: String(localized: "Разрешение на уведомления")
        case .other: String(localized: "Другое")
        }
    }

    private func kindText(_ kind: String?) -> String {
        switch kind {
        case "charge": String(localized: "Списание")
        case "trial": String(localized: "Окончание пробного периода")
        default: String(localized: "Недоступно")
        }
    }

    private func triggerText(_ triggerKind: String) -> String {
        switch triggerKind {
        case "calendar": String(localized: "Календарь")
        case "timeInterval": String(localized: "Интервал")
        default: String(localized: "Другое")
        }
    }
}
#endif
