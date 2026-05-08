import Foundation

enum LedgerError: LocalizedError, Equatable {
    case noActiveGame
    case nonPositiveAmount
    case selfTransfer
    case bankToBank
    case missingPlayer
    case tooFewPlayers
    case tooManyPlayers
    case cannotReverseOpening
    case playerBankrupt
    case creditAlreadyOutstanding
    case noCreditOutstanding

    var errorDescription: String? {
        switch self {
        case .noActiveGame: String(localized: "Нет активной игры.")
        case .nonPositiveAmount: String(localized: "Сумма должна быть больше нуля.")
        case .selfTransfer: String(localized: "Нельзя переводить самому себе.")
        case .bankToBank: String(localized: "Перевод от банка к банку не имеет смысла.")
        case .missingPlayer: String(localized: "Игрок не найден.")
        case .tooFewPlayers: String(localized: "Нужно как минимум двое игроков.")
        case .tooManyPlayers: String(localized: "Максимум — 8 игроков.")
        case .cannotReverseOpening: String(localized: "Стартовую раздачу нельзя отменить.")
        case .playerBankrupt: String(localized: "Игрок-банкрот не участвует в переводах.")
        case .creditAlreadyOutstanding: String(localized: "У игрока уже есть невозвращённый кредит.")
        case .noCreditOutstanding: String(localized: "У игрока нет невозвращённого кредита.")
        }
    }
}
