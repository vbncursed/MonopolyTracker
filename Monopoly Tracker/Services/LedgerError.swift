import Foundation

enum LedgerError: LocalizedError, Equatable {
    case noActiveGame
    case nonPositiveAmount
    case selfTransfer
    case bankToBank
    case missingPlayer
    case tooFewPlayers

    var errorDescription: String? {
        switch self {
        case .noActiveGame: String(localized: "Нет активной игры.")
        case .nonPositiveAmount: String(localized: "Сумма должна быть больше нуля.")
        case .selfTransfer: String(localized: "Нельзя переводить самому себе.")
        case .bankToBank: String(localized: "Перевод от банка к банку не имеет смысла.")
        case .missingPlayer: String(localized: "Игрок не найден.")
        case .tooFewPlayers: String(localized: "Нужно как минимум двое игроков.")
        }
    }
}
