<div align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Monopoly Tracker" />
  <h1>Monopoly Tracker</h1>
  <p>SwiftUI-приложение для бухгалтерии настольной Монополии: учёт игроков, переводов и истории партии.</p>
</div>

---

## Что это

Приложение **не** симулирует игру. Оно берёт на себя то, что плохо получается у людей за столом — деньги, счёт, журнал переходов. Идея проста: **журнал транзакций — единственный источник правды**, балансы выводятся из него.

- Создание новой игры с настраиваемым стартовым балансом и составом игроков.
- Переводы: игрок ↔ игрок, банк ↔ игрок, типы (аренда, зарплата, штраф, …), необязательный комментарий.
- Полная история — кто кому, когда и зачем.
- Сброс/завершение игры с сохранением истории.
- Овердрафт разрешён (как в реальной Монополии — банкротство это состояние, а не запрет операции).
- Тёмная/светлая/системная темы, переключение языка RU/EN без перезапуска.
- Apple Liquid Glass иконка (Light / Dark / Tinted).

## Стек

- **iOS 26.4+**, Swift 6.2, SwiftUI, SwiftData
- **Архитектура**: MVVM по умолчанию, MV там где `@Query` достаточно (см. `swiftui-view-refactor`).
- **Persistence**: `ModelContainer` инжектится через `AppContainer` (composition root). Все денежные операции идут через единственный `LedgerService` — это инвариант домена, проверенный тестами.
- **Локализация**: `Localizable.xcstrings` (ru-источник + en), runtime-свитч языка через swizzle `Bundle.localizedString`.

## Архитектура в одном экране

```
View (SwiftUI)
   │   @Environment(AppContainer)
   ▼
ViewModel или MV-View с @Query
   │
   ▼
LedgerService  ← единственный чокпоинт записи денежных движений
   │
   ▼
SwiftData (@Model: Game, Player, Transaction)
```

Domain-слой UI-агностичен: модели не знают про SwiftUI, форматирование живёт в `Money` / `FormatStyle`.

## Сборка и запуск

Проект — Xcode-таргет, без SPM/workspace. Схема — `Monopoly Tracker`.

```bash
# Сборка под Simulator
xcodebuild -project "Monopoly Tracker.xcodeproj" -scheme "Monopoly Tracker" \
  -destination 'generic/platform=iOS Simulator' build

# Все юнит-тесты на конкретном устройстве
xcodebuild -project "Monopoly Tracker.xcodeproj" -scheme "Monopoly Tracker" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Один тест
xcodebuild -project "Monopoly Tracker.xcodeproj" -scheme "Monopoly Tracker" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:'Monopoly TrackerTests/LedgerServiceTests/transfer_movesMoneyBetweenPlayers' test
```

В путях есть пробел — кавычки обязательны.

## Тесты

14 тестов на Swift Testing. Главное в `LedgerServiceTests`:

- Стартовая раздача создаёт по `gameStart`-транзакции на каждого игрока.
- Переводы корректно меняют оба баланса.
- Овердрафт разрешён — баланс может уйти в минус.
- Завершение игры проставляет `endedAt`, журнал не теряется.
- **Главный инвариант:** `Σ балансов игроков == N × startingBalance` при любом наборе внутренних переводов.

`TransferViewModelTests` фиксирует валидацию формы (positive amount, разные стороны), запись и сброс полей после успеха, корректный путь ошибки.

## Структура

```
Monopoly Tracker/
├─ App/                     # точка входа, AppContainer, AppearanceMode, LanguageMode + bundle swizzle
├─ Domain/                  # @Model + Money + расширения
├─ Services/                # LedgerService (protocol) + LiveLedgerService (@MainActor)
├─ Features/
│  ├─ Root/                 # таб-бар
│  ├─ NewGame/              # форма старта
│  ├─ Players/              # список с балансами (MV через @Query)
│  ├─ Transfer/             # форма перевода + ViewModel
│  ├─ History/              # журнал транзакций (MV)
│  └─ GameSettings/         # тема, язык, сброс, информация о версии
├─ Assets.xcassets/         # AppIcon (Light/Dark/Tinted) + AccentColor
└─ Localizable.xcstrings    # ru + en

Monopoly TrackerTests/      # Swift Testing
```

## Лицензия

[MIT](LICENSE) © 2026 vbncursed
