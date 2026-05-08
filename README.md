<div align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Monopoly Tracker" />
  <h1>Monopoly Tracker</h1>
  <p>SwiftUI-приложение для бухгалтерии настольной Монополии: учёт игроков, переводов и истории партии.</p>
</div>

---

## Что это

Приложение **не** симулирует игру. Оно берёт на себя то, что плохо получается у людей за столом — деньги, счёт, журнал переходов. Идея проста: **журнал транзакций — единственный источник правды**, балансы выводятся из него.

- Создание новой игры с настраиваемым стартовым балансом и составом игроков (имена могут повторяться — игроки различаются цветом фишки и местом за столом).
- Переводы: игрок ↔ игрок, банк ↔ игрок, типы (аренда, зарплата, штраф, …), необязательный комментарий.
- Полная история — кто кому, когда и зачем; сохраняется даже после удаления игрока (имена денормализованы в записи).
- Сброс/завершение игры с сохранением истории.
- Овердрафт разрешён (как в реальной Монополии — банкротство это состояние, а не запрет операции).
- Тёмная/светлая/системная темы, переключение языка RU/EN без перезапуска.
- Apple Liquid Glass иконка (Light / Dark / Tinted).

## Стек

- **iOS 26.4+**, Swift 6.2 toolchain, SwiftUI, SwiftData
- **Архитектура**: MVVM по умолчанию, MV там где `@Query` достаточно (см. `swiftui-view-refactor`).
- **Persistence**: `ModelContainer` инжектится через `AppContainer` (composition root). Все денежные операции идут через единственный `LedgerService` — это инвариант домена, проверенный тестами. SwiftData `#Index` на горячих полях (`Transaction.timestamp/fromPlayerID/toPlayerID`, `Game.endedAt/startedAt`).
- **Локализация**: `Localizable.xcstrings` (ru-источник + en), runtime-свитч языка через swizzle `Bundle.localizedString` без перезапуска.
- **Производительность**: дебаунс 150 мс на ввод суммы, fan-out `[UUID: Money]` вместо per-row reduce, `Equatable` на строках списка игроков.

## Архитектура в одном экране

```
View (SwiftUI)
   │   @Environment(AppContainer)
   ▼
ViewModel (только когда нужна форма + submit) или MV-View с @Query
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

# Все юнит-тесты
xcodebuild -project "Monopoly Tracker.xcodeproj" -scheme "Monopoly Tracker" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Один тест
xcodebuild -project "Monopoly Tracker.xcodeproj" -scheme "Monopoly Tracker" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:'Monopoly TrackerTests/LedgerServiceTests/transfer_movesMoneyBetweenPlayers' test
```

В путях есть пробел — кавычки обязательны.

## Метрики

Замерено на Release-сборке, iPhone 17 Pro Simulator (iOS 26.4.1).

| Метрика | Значение |
|---|---|
| Cold launch (`simctl launch` → return) | **305 мс** |
| Physical footprint (idle, через 3 с) | **27.2 МБ** |
| Peak footprint | 27.2 МБ |
| Размер бандла | **3.4 МБ** (Assets.car — 2.0 МБ под три варианта иконки, бинарь — 1.4 МБ) |
| Кодовая база | 1 526 строк Swift |
| Прогон 14 тестов (build + install + run) | ~34 с |
| Чистое выполнение тестов | ~0.6 с |
| Самый быстрый / медленный тест | 19 мс / 71 мс |

## Тесты

14 тестов на Swift Testing. Главное в `LedgerServiceTests`:

- Стартовая раздача создаёт по `gameStart`-транзакции на каждого игрока.
- Переводы корректно меняют оба баланса.
- Овердрафт разрешён — баланс может уйти в минус.
- Дубликаты имён разрешены (игроки идентифицируются по `UUID`).
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
│  ├─ Root/                 # таб-бар (всегда виден)
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
