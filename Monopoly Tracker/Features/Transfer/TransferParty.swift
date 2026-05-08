import Foundation

/// Сторона перевода: банк или конкретный игрок.
enum TransferParty: Hashable {
    case bank
    case player(UUID)

    var isBank: Bool {
        if case .bank = self { return true }
        return false
    }
}
