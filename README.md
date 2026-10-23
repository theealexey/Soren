# Soren

**Subscriptions, recurring obligations, and a clearer view of what is scheduled next.**

Soren is an iOS-first app for organizing subscriptions and other recurring commitments. It brings upcoming charges, renewal schedules, lifecycle states, and normalized recurring costs into one place—without pretending to be a banking app.

> **Status:** Under active development. This repository does not currently publish a packaged app release.

## What Soren does

- **Overview** — see the month's scheduled amount, upcoming charges, and counts of active, trial, and paused subscriptions.
- **Subscriptions** — manage recurring items, inspect their details, and keep track of billing cycles and lifecycle states.
- **Calendar** — explore projected charges by date, based on each item's recurrence rules.
- **Analytics** — compare normalized monthly and annual costs, see category and subscription breakdowns, and review a six-month schedule forecast.
- **Reminders** — manage notifications associated with recurring obligations.
- **Currencies** — work with supported currencies; analytics distinguishes complete, partial, and unavailable conversion data rather than silently treating missing values as zero.

### Schedule truth, not transaction history

Soren primarily knows **what is scheduled** from the recurring information you maintain. A projected charge is **not** confirmation that money was withdrawn. Without a transaction integration, Soren cannot verify successful payments, declined cards, or payment attempts.

Two numbers that may appear together have different meanings:

- **Normalized cost:** a monthly or annual equivalent of current recurring obligations.
- **Schedule forecast:** monetary events projected for specific calendar dates.

These are deliberately separate calculations. Trial endings are not automatically treated as monetary charges.

## Technology

| Area | Implementation |
| --- | --- |
| Platform | iOS 18.0+ |
| Language | Swift 6, strict concurrency checking |
| Interface | SwiftUI |
| Persistence | SwiftData |
| Concurrency | Swift Concurrency |
| Architecture | Feature-based presentation, domain use cases, repository contracts, dependency injection |
| Tests | Swift Testing and UI tests |
| Localization | Russian and English via String Catalog |

The interface uses a restrained light/dark design language, with native system APIs where supported and fallbacks for older deployment versions. The project includes a widget target, but the widget extension is not yet wired into the main app build.

## Getting started

**Requirements**

- A Mac with Xcode installed (the checked-in `project.yml` currently specifies Xcode 26.3).
- An iOS 18.0+ simulator or compatible device.
- A suitable signing team if running on a physical device.

```bash
git clone https://github.com/theealexey/Soren.git
cd Soren
open Soren.xcodeproj
```

In Xcode, select the **Soren** scheme and an available iOS simulator, then build and run.

The repository also contains `project.yml`, but opening the checked-in `Soren.xcodeproj` does not require regenerating the project.

## Project structure

```text
Soren/
├── App/            # App entry, composition root, navigation
├── Core/           # Design system, formatters, shared services
├── Domain/         # Entities, contracts, use cases, recurrence projection
├── Data/           # SwiftData, mappers, repositories, supporting data
└── Features/       # Overview, subscriptions, calendar, analytics, and flows
SorenTests/         # Domain, data, and presentation tests
SorenUITests/       # UI regression tests
SorenWidgets/       # Widget target (integration pending)
```

The **Domain** layer has no SwiftUI or SwiftData dependency. Presentation consumes domain-facing use cases and state; persistence is kept behind repository boundaries.

Recurring occurrences are projected through the canonical schedule projector rather than independently recalculated in each view.

## Building and testing

For command-line builds and tests, disable generated localization-string extraction to avoid unrelated String Catalog changes:

```bash
xcodebuild \
  -project Soren.xcodeproj \
  -scheme Soren \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  SWIFT_EMIT_LOC_STRINGS=NO \
  build
```

```bash
xcodebuild \
  -project Soren.xcodeproj \
  -scheme Soren \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -testLanguage ru \
  -testRegion RU \
  SWIFT_EMIT_LOC_STRINGS=NO \
  test
```

Replace the simulator name with one installed in your Xcode environment. The explicit Russian locale reflects the current regression-test baseline, not a restriction of the app's supported languages.

## Development status

Soren is being developed iteratively. Features, presentation, and internal APIs may change before a public release. No App Store availability, bank connection, or transaction-sync functionality is implied by this repository.

## License

No license has been published for this repository. Public source availability does **not** grant permission to copy, modify, or redistribute the code.
