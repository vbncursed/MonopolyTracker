# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Product

A SwiftUI iOS app for the **Monopoly board game**. The app does not simulate the board — it tracks the bookkeeping that humans do badly during a real physical game:

- Add / remove players, set a configurable starting balance per game.
- Transfer money between players (player ↔ player, bank ↔ player) with kind (transfer / bankPayout / bankCollect / rent / salary / fee / gameStart / custom) and an optional note.
- Full transaction history (who paid whom, how much, when, why).
- Reset / start a new game (zero out state).
- Per-player balance derived from the transaction log (single source of truth).
- Light / dark / system theme, RU/EN language switch with no app restart.

When designing models and UI, treat **the transaction log as the source of truth** and balances as derived values. Never mutate a player's balance directly without recording the corresponding transaction — otherwise history and balances will drift.

## Build / Run / Test

The project is an Xcode project (no SPM / no workspace). Scheme: `Monopoly Tracker`. Deployment target: **iOS 26.4**, Swift 6.2 toolchain.

```bash
# Build (default destination — generic iOS Simulator)
xcodebuild -project "Monopoly Tracker.xcodeproj" -scheme "Monopoly Tracker" \
  -destination 'generic/platform=iOS Simulator' build

# All unit tests on a concrete simulator
xcodebuild -project "Monopoly Tracker.xcodeproj" -scheme "Monopoly Tracker" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Single test
xcodebuild -project "Monopoly Tracker.xcodeproj" -scheme "Monopoly Tracker" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:'Monopoly TrackerTests/LedgerServiceTests/transfer_movesMoneyBetweenPlayers' test
```

The path contains a space — always quote `"Monopoly Tracker.xcodeproj"` and the `-only-testing:` argument.

## Architecture

The app is a working SwiftUI + SwiftData app organised around three layers:

```
View / ViewModel  ──▶  LedgerService (protocol)  ──▶  SwiftData @Model
   (SwiftUI)                  (@MainActor)                (Game, Player, Transaction)
```

- **Composition root.** `AppContainer` (`@Observable`, `@MainActor`) owns the `ModelContainer` and exposes `ledger: LedgerService`. It is injected via `.environment(container)` at the App scene root and read with `@Environment(AppContainer.self)`.
- **`LedgerService` is the only chokepoint for money movement.** Every `Transaction` is created inside `LiveLedgerService`. No view, no view model, no other service may call `modelContext.insert(Transaction(...))`. This invariant is what makes the balance computation valid; tests pin it (`balanceInvariant_sumOverPlayersEqualsSumOfStartingBalances`).
- **`LiveLedgerService` retains its `ModelContainer`** (`init(container:)`). Earlier the service took only a `ModelContext` — but `ModelContext` weakly references its container, so under tests where the container was discarded after construction (`let (service, _) = makeService()`), every model instance got invalidated mid-test (`ModelContext.reset` fatal). Keep the strong container reference in the service.
- **Domain models** (`Domain/`):
  - `Game` — settings + lifecycle, `@Index<Game>([\.endedAt], [\.startedAt])`.
  - `Player` — name, color, seat order. **No stored `balance`** — balance is computed from transactions.
  - `Transaction` — `from/toPlayerID: UUID?` (nil = bank), denormalised `from/toPlayerName` so history survives player removal. `@Index<Transaction>([\.timestamp], [\.fromPlayerID], [\.toPlayerID])`.
  - `Money = Decimal`, formatted via `.formatted(.monopolyMoney)` (FormatStyle, never `String(format:)` per `swift-format-style`).
- **Views.** Default to **MV** (no view model) when `@Query` is the entire data flow — `PlayersListView`, `HistoryView` follow this. Introduce a `ViewModel` only when there is non-trivial form state and submit logic — `TransferViewModel` is the only one. SwiftUI's tabs are always visible; `RootView` is a `TabView` and the first tab routes to `NewGameView` if `activeGames.isEmpty`, else to `PlayersListView`. Never present `NewGameView` as a `fullScreenCover` over the tabs — it hides the tab bar.
- **Active-game scoping for `@Query`.** Every player/transaction query that drives the live UI filters with `#Predicate { $0.game?.endedAt == nil }` so that data from finished games never leaks into the new round. This applies to `PlayersListView`, `TransferView` (via `PartyPicker`), and `HistoryView`. Old games stay in the DB (history requirement) but invisible after a reset.
- **App-level state** lives in `App/` as `@AppStorage`-backed enums: `AppearanceMode` (`system/light/dark` → `.preferredColorScheme(...)`), `LanguageMode` (`system/ru/en` → `BundleLanguageOverride.apply` + `.id(languageMode)` to force re-render of localized text).

### Persistence container fallback

`Monopoly_TrackerApp.makeContainer(schema:)` tries the disk store first; on **any** error (including sandbox failures when launched as a unit-test host) it falls back to in-memory. Without this fallback the test runner crashes before any test can register, because the test host's app sandbox sometimes can't create `Application Support/default.store`.

### Localization

- `Localizable.xcstrings` is the source of truth, `sourceLanguage = "ru"`, every key has explicit `ru` and `en` `stringUnit`s — without explicit `ru` entries Xcode does not emit `ru.lproj/Localizable.strings` and the runtime swizzle has nothing to load.
- `BundleLanguageOverride` swizzles `Bundle.localizedString(forKey:value:table:)` to read from a per-language `Bundle` associated with `Bundle.main`. The App calls `apply(_:)` on init (before first view is built) and on `onChange(of: languageMode)`. The view tree carries `.id(languageMode)` so SwiftUI rebuilds every `Text` after a language change.
- Plain-string sources (`TransactionKind.displayName`, `LedgerError.errorDescription`, `AppearanceMode.displayName`) all go through `String(localized:)` — they pass through the same swizzled bundle.

## Performance patterns to keep

- **Hero-zone-above-Form for input fields.** A `TextField` inside a SwiftUI `Form` on iOS 26 forces a diffable layout pass on every keystroke — visible lag on the first digit and ongoing hitches. The amount field in `TransferView` lives in a separate `VStack` *above* the Form (`amountHero`), not inside any `Section`. The Form below is unaffected by typing.
- **Keep amount out of `@Observable`.** `TransferViewModel` does **not** store the amount — it's a parameter to `submit(amount:)` and `canSubmit(amount:)`. Amount lives only as `@State amountText: String` in the view; typing never mutates observable state, so observation never fans out to disabled-state evaluations or other vm-bound subviews.
- **Auto-format input via `.onChange`.** `amountText` is reformatted on every change via `Decimal.FormatStyle.monopolyDigits` (locked `en_US` locale → comma separators independent of UI language). Idempotent fixed point: `"1500"` → `"1,500"` → no further change. **`Money(parsing:)` strips to digits only** — never interpret `","` as a decimal separator, otherwise the freshly formatted `"1,000"` parses back to `Decimal(1.000) = 1` (the infamous `1000+500=501` bug).
- **Tap-to-dismiss keyboard via `simultaneousGesture`.** `Form` swallows ordinary `.onTapGesture`. Use `.simultaneousGesture(TapGesture().onEnded { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) })` on the Form-containing view. Scope it to the area where dismiss is desired — don't put it on the parent of a focusable hero (it races with focus-set gestures).
- **One fan-out pass, not per-row reduces.** `PlayersListView` builds a `[UUID: Money]` balances map once per render, then passes the precomputed balance into each row. Doing the reduce per row was O(N×M); the map is O(N+M).
- **`Equatable` on rows that are cheap to compare and expensive to rebuild.** `PlayerRowView` conforms to `Equatable` keyed on player identity + balance — SwiftUI short-circuits unchanged rows.
- **Use SwiftData `#Index`** on hot fields. `Transaction` has indexes for `timestamp`, `fromPlayerID`, `toPlayerID`; `Game` for `endedAt`, `startedAt`. **`#Index` may appear at most once per `@Model`** — combine multiple key paths into a single call: `#Index<T>([\.a], [\.b], [\.c])`.

## Operational gotchas (host environment)

These have bitten this project once and may bite again:

- **Simulator won't boot, `launchd_sim could not bind to session`.** Root cause was a missing `/private/var/tmp` directory — `launchd_sim` `mkdir`s its temp state there and crashes when the parent doesn't exist. Fix: `sudo mkdir -p /private/var/tmp && sudo chmod 1777 /private/var/tmp && sudo chown root:wheel /private/var/tmp`. Reboot does not help.
- **xctrace Time Profiler hangs on the iOS Simulator.** Don't try to capture traces via `xcrun xctrace record` against a sim device — it produces no output. Use Xcode's Instruments.app (Cmd+I) on a real device or sim run.
- **`#Index` macro emits `#Index can only be used once per PersistentModel`** if you write multiple `#Index<T>([...])` lines. Combine into one call with several arrays.
- **`Money == Decimal` aliasing trap.** Defining `extension Money { init?(string: String) {...} }` shadows Foundation's `Decimal.init?(string:locale:)` and `Decimal(string: cleaned)` inside our init recurses into itself → `EXC_BAD_ACCESS`. Use a unique argument label (`init?(parsing input: String)`).
- **`@Query` macro vs. our `Transaction` type.** SwiftData's `@Query` macro has an overload with a `transaction:` parameter (CoreData/animation). Using `@Query(filter: #Predicate<Transaction> { ... })` confuses SourceKit's macro resolution and emits `Macro 'Query(filter:sort:transaction:)' requires that 'Transaction' conform to 'PersistentModel'` together with a cascade of `Cannot find type 'Transaction'` errors. **The build itself is clean** — these are SourceKit indexer false positives. Don't rename the type; just rebuild and ignore the indexer noise.
- **SourceKit also intermittently flags `import UIKit` as `No such module 'UIKit'`** in iOS-target Swift files (e.g. `TransferView.swift` after adding the keyboard-dismiss UIKit call). Same story — indexer-only, build is fine.

## Reset semantics

"Reset the game" ends the current `Game` (sets `endedAt`); it does not delete transactions. Preserving history is a product requirement.

## Conventions

- SwiftUI + SwiftData only — no UIKit unless unavoidable. No third-party deps unless asked.
- Communicate with the user in Russian when they write in Russian (this project's working language).
- **File length cap: 300 lines.** Split aggressively before crossing the line — extract subviews into their own files, lift services/utilities into dedicated types. Test files are exempt; this is a production-code rule.
- Player names may repeat — players are identified by `UUID`. The UI surfaces seat number + color so duplicates remain distinguishable.
- Do not commit `.claude/`, `myview.png`, or `Launch_*.trace/` (all in `.gitignore`).
- **All 13 installed Swift/SwiftUI skills must be exercised across this project** — invoke each at the moment it applies; do not skip them:
  - `swift-api-design-guidelines-skill` — when designing public types, naming, argument labels.
  - `swift-architecture-skill` — when laying out modules / picking MVVM vs MV vs TCA.
  - `swift-concurrency-pro` + `swift-concurrency-expert` — any `async`/`await`, actors, `@MainActor`, Sendable.
  - `swift-format-style` — money / date formatting (`.formatted(.currency(code:))`, never `String(format:)`).
  - `swift-testing-pro` — writing tests (prefer Swift Testing over XCTest where possible).
  - `swiftdata-pro` — every `@Model`, `@Query`, `ModelContext`, `#Index` change.
  - `swiftui-design-principles` — high-level UX/visual decisions.
  - `swiftui-liquid-glass` — iOS 26+ glass surfaces (`.buttonStyle(.glassProminent)` for primary actions, `.glass` for secondary).
  - `swiftui-performance-audit` — when lists/animations feel slow or before shipping.
  - `swiftui-pro` — general SwiftUI review pass on new views.
  - `swiftui-ui-patterns` — navigation, modifiers, responsive layout.
  - `swiftui-view-refactor` — splitting views, MV-over-MVVM, stable view trees, DI.
