# String Catalog Migration (P0)

## Проблема
100+ хардкоженных русских строк в 16 View/ViewModel файлах не обёрнуты в `String(localized:)`. Это блокирует будущую локализацию и нарушает стандарт проекта.

## Подход
`sourceLanguage` в xcstrings = `"ru"`, значит Xcode автоматически подхватит строки из `String(localized:)` при сборке. Не нужно вручную редактировать xcstrings — компилятор сам добавит новые ключи.

Оборачиваем ВСЕ пользовательские строки в `String(localized:)`. Для SwiftUI `.navigationTitle`, `SectionHeader`, `Text()` — они принимают `LocalizedStringKey` автоматически, но для consistency и явности всё равно используем `String(localized:)` в параметрах типа `String`.

## Файлы и строки для миграции

### Batch 1 — Home + Components (6 файлов)
1. **HomeView.swift** — 7 строк: navigationTitle, accessibilityLabel, accessibilityHint, ErrorStateView, EmptyStateView
2. **FinancialSnapshotSection.swift** — 3 строки: SectionHeader, StatBlock titles
3. **UpcomingChargesSection.swift** — 1 строка: SectionHeader
4. **ActiveTrialsSection.swift** — 1 строка: SectionHeader
5. **QuickInsightsSection.swift** — 1 строка: SectionHeader

### Batch 2 — ItemDetails (2 файла)
6. **ItemDetailsView.swift** — 12 строк: SectionHeader, infoRow labels, StatBlock titles, Button
7. **ItemEditFormView.swift** — 14 строк: navigationTitle, Button labels, Section headers, TextField placeholders, Picker labels, DatePicker labels

### Batch 3 — Library + Alerts (2 файла)
8. **LibraryView.swift** — 8 строк: navigationTitle, searchable, ErrorStateView, EmptyStateView, noResults texts
9. **AlertsView.swift** — 4 строки: navigationTitle, ErrorStateView, EmptyStateView

### Batch 4 — AddSubscription (2 файла)
10. **SubscriptionFormView.swift** — 14 строк: Button, Section headers, TextField placeholders, Picker labels, DatePicker labels
11. **ProviderPickerView.swift** — 4 строки: navigationTitle, searchable, Text, SectionHeader

### Batch 5 — Settings + Placeholders (5 файлов)
12. **SettingsView.swift** — 11 строк: navigationTitle, Button, Section headers, Picker labels, Stepper labels, Text labels
13. **HomePlaceholderView.swift** — 3 строки
14. **LibraryPlaceholderView.swift** — 3 строки
15. **CalendarPlaceholderView.swift** — 3 строки
16. **AnalyticsPlaceholderView.swift** — 3 строки

## Правила миграции
- `SectionHeader("Текст")` → `SectionHeader(String(localized: "Текст"))`
- `title: "Текст"` (String параметр) → `title: String(localized: "Текст")`
- `Text("Текст")` → `Text(String(localized: "Текст"))` ИЛИ оставить как есть (Text принимает LocalizedStringKey), но для единообразия оборачиваем
- `.navigationTitle("Текст")` — принимает LocalizedStringKey, но для consistency оборачиваем
- Строки с интерполяцией `"Текст \(var)"` → `String(localized: "Текст \(var)")` (автоматически создаёт форматирование)
- Строки в preview-блоках — НЕ трогаем (они не для пользователя)
- AccessibilityLabel/Hint — тоже оборачиваем

## После миграции
- Build проекта (xcstrings обновится автоматически)
- Проверить что новые ключи появились в Localizable.xcstrings
- Commit + push
