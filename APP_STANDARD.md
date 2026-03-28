# Soren App Engineering & Design Standard

> Код и UX уровня **senior Cupertino quality** — чистая архитектура, нулевой хаос в слоях, премиальная визуальная и продуктовая полировка.

---

## 1. Product Quality Bar

Каждая фича должна:
- быть понятной с первого экрана без обучения;
- быть консистентной по навигации, состояниям, иерархии текста;
- работать плавно (60fps), предсказуемо и без визуального шума;
- быть тестируемой и масштабируемой.

---

## 2. Architecture (Clean + SOLID)

### 2.1 Layer boundaries
- **Domain**: сущности, value objects, use cases, протоколы репозиториев. Импортирует **только Foundation**. Без SwiftUI, UIKit, SwiftData.
- **Data**: конкретные реализации репозиториев, persistence, mappers, API-клиенты.
- **Presentation (Features + Core)**: View, ViewModel, Design System, UI-расширения доменных типов.

### 2.2 Dependency rule
- Зависимости только "внутрь":
  - Presentation → Domain (протоколы, use cases)
  - Data → Domain (протоколы)
- Domain **никогда** не импортирует UI или инфраструктуру.
- UI-расширения доменных enum (color, icon) живут в `Core/DesignSystem/Extensions/`.

### 2.3 SOLID policy
- **S**: один тип = одна ответственность.
- **O**: расширяем через композицию и протоколы, не copy-paste.
- **L**: все реализации протокола взаимозаменяемы.
- **I**: узкие протоколы вместо god protocol.
- **D**: use cases и view models зависят от `any Protocol`, не от concrete типов.

### 2.4 DI policy
- Все зависимости инъектятся через инициализатор.
- Composition root — `AppContainer`.
- `RepositoryContainer` экспонирует только протоколы (`any RecurringItemRepository`).
- Запрещён runtime service locator внутри view model.

---

## 3. Anti-Hardcode

### 3.1 Что запрещено хардкодить
- URL/ID внешних сервисов в UI или domain-логике.
- Валюту и формат даты в domain-логике (допустим дефолт в init, но расчёты через policy).

### 3.2 Допустимые значения в коде
- **Дефолты в инициализаторах**: `currencyCode: String = "RUB"` — это не hardcode, а разумный дефолт для целевого рынка. Перекрывается при создании.
- **UX-константы с очевидным смыслом**: `prefix(5)` для превью, пороги `<=3` для предупреждений — выносить в конфиг нет смысла, пока нет A/B тестирования.
- **SF Symbol имена** в presentation-слое.
- **Технические литералы**: `0`, `1`, `12` в арифметике (`monthlyTotal * 12`).

### 3.3 Design tokens — обязательны
- Все отступы через `Spacing`, типографика через `Typography`, цвета через `ColorTokens`.
- Тени через `ShadowTokens`, анимации через `MotionTokens`.
- Никаких inline `.font(.system(size: 14))` или `.padding(16)` — только токены.

### 3.4 Локализация (roadmap)
- **Текущий этап**: RU-only, строки в коде. Допустимо — одноязычное приложение.
- **При добавлении второго языка**: миграция на String Catalog, вынос всех UI-строк. До этого момента — не создаём пустую инфраструктуру.

---

## 4. ViewModel & State

- ViewModel не импортирует SwiftUI (только Foundation).
- `@MainActor @Observable` — стандартный паттерн.
- Обязательные состояния экрана:
  - `loading` — при первой загрузке
  - `content` — данные получены
  - `empty` — данных нет (с CTA)
  - `error` — с возможностью retry
- ViewModel предоставляет presentation-ready данные. View не содержит бизнес-логики.

---

## 5. Domain Modeling

- Сущности — `struct`, `Sendable`, value semantics.
- Бизнес-инварианты проверяются в domain (инициализаторы/computed properties).
- Computed properties для derived данных (`monthlyEquivalent`, `isActiveTrial`).
- Enums для закрытых наборов значений с exhaustive switch.

---

## 6. Data Layer

- Репозитории скрывают детали persistence за протоколами.
- Mapper — отдельный тип, детерминированный, покрытый тестами.
- `@Model` классы не утекают за пределы Data-слоя.
- `@MainActor` на репозиториях — SwiftData constraint, не архитектурный выбор.

---

## 7. Premium Design

### 7.1 Visual system
- Иерархия информации: 1 primary action per screen.
- Цвета только через semantic tokens. Никаких `.red`, `.blue` inline.
- Ритм отступов по 4pt grid через `Spacing` токены.

### 7.2 Motion & haptics
- Анимации через `MotionTokens` — короткие, purpose-driven.
- Haptics через `HapticEngine` — только в моментах подтверждения/ошибки/действия.
- **Roadmap**: Respect `Reduce Motion` (accessibilityReduceMotion).

### 7.3 Accessibility (roadmap)
- **Текущий этап**: семантические цвета, разумные touch targets.
- **Следующий этап**: Dynamic Type, VoiceOver labels/hints, touch targets >= 44x44, цвет не единственный носитель смысла. Отдельная сессия.

### 7.4 Copywriting
- Короткие, ясные, уверенные формулировки.
- Единый tone of voice. Без смешения RU/EN в пользовательском UI.
- Технические placeholder экраны (Calendar, Analytics, Settings) — допустимо EN до реализации.

---

## 8. Performance

- Main-thread — UI и SwiftData persistence (обязательное ограничение).
- Скролл и переходы без лагов.
- `LazyVStack` для длинных списков.
- Crash-free как базовое требование.

---

## 9. Testing

### 9.1 Минимальный набор на фичу
- **Unit**: use cases, mappers, domain computed properties.
- **ViewModel**: проверка state transitions (load → content/error/empty).

### 9.2 Подход
- Тесты должны быть **агрессивными** — пытаться сломать код, а не подтвердить happy path.
- Граничные значения, nil, пустые коллекции, некорректные данные.
- Каждый баг-фикс сопровождается регрессионным тестом.

### 9.3 Roadmap
- **Snapshot tests**: когда UI стабилизируется.
- **UI tests**: critical user flows (добавление подписки, фильтрация).

---

## 10. PR Quality Gate

PR не проходит, если:
- [ ] Нарушены layer boundaries или DIP
- [ ] Domain импортирует SwiftUI/SwiftData
- [ ] Use cases/VM зависят от concrete типов
- [ ] Нет обработки empty/error/loading
- [ ] UI использует inline стили вместо design tokens
- [ ] Нет тестов на новую бизнес-логику

---

## 11. Definition of Done

Фича готова когда:
1. Соответствует SOLID и layer boundaries.
2. UI использует только design tokens.
3. Все состояния экрана реализованы.
4. Критичная логика покрыта тестами.
5. Билд проходит без ошибок и warnings.
6. Код прошёл self-review по чеклисту выше.
