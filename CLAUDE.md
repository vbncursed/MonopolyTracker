# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Product

A SwiftUI iOS/macOS companion app for the **Monopoly board game**. The app does not simulate the board — it tracks the bookkeeping that humans do badly during a real physical game:

- Add / remove players, set a configurable starting balance per game.
- Transfer money between players (player ↔ player, bank ↔ player).
- Full transaction history (who paid whom, how much, when, why).
- Reset / start a new game (zero out state).
- Per-player balance derived from the transaction log (single source of truth).

When designing models and UI, treat **the transaction log as the source of truth** and balances as derived values. Never mutate a player's balance directly without recording the corresponding transaction — otherwise history and balances will drift.

## Build / Run / Test

The project is an Xcode project (no SPM / no workspace). Scheme: `Monopoly Tracker`.

```bash
# Build (default destination — generic iOS Simulator)
xcodebuild -project "Monopoly Tracker.xcodeproj" -scheme "Monopoly Tracker" -destination 'generic/platform=iOS Simulator' build

# Run all unit + UI tests on a concrete simulator (pick any installed iPhone runtime)
xcodebuild -project "Monopoly Tracker.xcodeproj" -scheme "Monopoly Tracker" -destination 'platform=iOS Simulator,name=iPhone 15' test

# Run a single test (Swift Testing or XCTest), use -only-testing:<Target>/<Suite>/<Test>
xcodebuild -project "Monopoly Tracker.xcodeproj" -scheme "Monopoly Tracker" -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:'Monopoly TrackerTests/Monopoly_TrackerTests/example' test
```

The path contains a space — always quote `"Monopoly Tracker.xcodeproj"` and the `-only-testing:` argument.

## Architecture

Current state of the repo: this is the **Xcode SwiftUI + SwiftData starter template**, not yet feature code. `Item.swift` / `ContentView.swift` are template scaffolding to be replaced. When implementing features:

- **Persistence: SwiftData.** `Monopoly_TrackerApp` declares the `ModelContainer` and injects it via `.modelContainer(...)`. New `@Model` types must be added to the `Schema([...])` array in `Monopoly_TrackerApp.swift` or they will not be persisted. Prefer evolving the existing container over creating ad-hoc ones.
- **Domain models to introduce** (replacing `Item`): at minimum `Game` (settings + lifecycle), `Player` (name, color/avatar, ordering), and `Transaction` (from, to, amount, kind: transfer/bank-payout/bank-collect/rent/etc., timestamp, optional note). Model `Player.balance` as a computed property over transactions, not a stored field.
- **Reset semantics:** "reset the game" should be implemented as ending the current `Game` and starting a new one (or archiving), not as deleting all transactions — preserving history is a product requirement.
- **Views:** SwiftUI with `@Query` for live-updating lists; mutations go through `@Environment(\.modelContext)`. Keep transaction recording in a single chokepoint (e.g. a `GameStore` / service) so every money movement produces exactly one `Transaction`.

## Conventions

- SwiftUI + SwiftData only — no UIKit unless unavoidable. No third-party deps unless asked.
- Communicate with the user in Russian when they write in Russian (this project's working language).
- **File length cap: 300 lines.** Split aggressively before crossing the line — extract subviews into their own files, lift services/utilities into dedicated types. Test files are exempt; this is a production-code rule.
- **All 13 installed Swift/SwiftUI skills must be exercised across this project** — the user explicitly wants them all used. Invoke each at the moment it applies; do not skip them:
  - `swift-api-design-guidelines-skill` — when designing public types, naming, argument labels.
  - `swift-architecture-skill` — when laying out modules / picking MVVM vs MV vs TCA.
  - `swift-concurrency-pro` + `swift-concurrency-expert` — any `async`/`await`, actors, `@MainActor`, Sendable.
  - `swift-format-style` — money / date formatting (`.formatted(.currency(code:))`, never `String(format:)`).
  - `swift-testing-pro` — writing tests (prefer Swift Testing over XCTest where possible).
  - `swiftdata-pro` — every `@Model`, `@Query`, `ModelContext` change.
  - `swiftui-design-principles` — high-level UX/visual decisions.
  - `swiftui-liquid-glass` — iOS 26+ glass surfaces (this project targets a 2026 SDK).
  - `swiftui-performance-audit` — when lists/animations feel slow or before shipping.
  - `swiftui-pro` — general SwiftUI review pass on new views.
  - `swiftui-ui-patterns` — navigation, modifiers, responsive layout.
  - `swiftui-view-refactor` — splitting views, MV-over-MVVM, stable view trees, DI.
