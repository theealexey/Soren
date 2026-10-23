# Soren

**A clearer view of subscriptions and recurring obligations.**

Soren is an iOS app for understanding what you subscribe to, when your recurring obligations are scheduled, and what they cost over time.

It combines a focused interface with calendar-based projections and transparent cost calculations. Instead of trying to imitate a bank statement, Soren works from the recurring schedules you maintain.

## Explore Soren

| Section | What it helps you understand |
| --- | --- |
| **Overview** | This month's scheduled charges, the next upcoming occurrences, and subscription lifecycle counts. |
| **Subscriptions** | Your recurring items, billing cycles, details, and management actions. |
| **Calendar** | Which monetary occurrences are projected for a given date or month. |
| **Analytics** | Normalized monthly and annual costs, cost composition, categories, and a six-month schedule forecast. |

Soren also supports subscription lifecycle states, trial periods, reminders, and multiple currencies. Analytics distinguishes complete and incomplete currency-conversion data rather than presenting an incomplete calculation as a complete total.

## Built around schedule truth

A scheduled charge is **not** a verified payment.

Soren projects recurring obligations from their dates and recurrence rules. It does not infer whether a bank transaction succeeded, a card was declined, or a payment attempt took place.

Two related views of cost are intentionally kept distinct:

- **Normalized cost** expresses current recurring obligations as comparable monthly or annual equivalents.
- **Schedule forecast** shows projected monetary occurrences on actual calendar dates.

A trial ending is not itself treated as a monetary charge. The calendar and analytics use the same canonical schedule projection rather than maintaining competing recurrence rules.

## Technology

| | |
| --- | --- |
| **Platform** | iOS 18+ |
| **Language** | Swift 6 with strict concurrency checking |
| **UI** | SwiftUI |
| **Persistence** | SwiftData |
| **Concurrency** | Swift Concurrency |
| **Localization** | Russian and English, String Catalog |
| **Testing** | Swift Testing and Xcode UI tests |

The app uses a feature-oriented presentation layer, domain use cases, repository contracts, and dependency injection. Domain logic is independent of SwiftUI and SwiftData; persistence details stay behind infrastructure boundaries.

The interface supports Light and Dark appearances, native Apple visual APIs where available, and appropriate fallbacks on older supported iOS versions.

## Repository structure

```text
Soren/
├── App/            App entry point, composition, navigation
├── Core/           Design system, formatting, shared services
├── Domain/         Entities, business rules, repository contracts, use cases
├── Data/           SwiftData, mappers, repositories
└── Features/       Overview, subscriptions, calendar, analytics
SorenTests/         Unit and integration tests
SorenUITests/       UI regression tests
Soren.xcodeproj/    Xcode project
project.yml         Project configuration
```

## Build and run

You need Xcode and an iOS 18+ simulator or compatible device.

```bash
git clone https://github.com/theealexey/Soren.git
cd Soren
open Soren.xcodeproj
```

Choose the **Soren** scheme and an available simulator in Xcode, then build and run. Device builds require an appropriate Apple development signing configuration.

## Tests

The Xcode **Soren** scheme contains unit and UI tests. For command-line runs, set `SWIFT_EMIT_LOC_STRINGS=NO` to prevent build-time localization extraction from modifying the String Catalog.

```bash
xcodebuild \
  -project Soren.xcodeproj \
  -scheme Soren \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -testLanguage ru -testRegion RU \
  SWIFT_EMIT_LOC_STRINGS=NO \
  test
```

Replace the simulator name with a device available in your Xcode installation. The explicit `ru/RU` configuration is the project's current deterministic regression-test environment.
