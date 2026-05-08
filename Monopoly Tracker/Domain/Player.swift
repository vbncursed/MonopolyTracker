import Foundation
import SwiftData

@Model
final class Player {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var seatOrder: Int
    /// Балланс ушёл ниже floor — игрок выбыл, в transfer'ах не участвует.
    var isBankrupt: Bool
    /// Активен невозвращённый кредит. Один кредит за раз, нельзя взять второй
    /// до возврата.
    var hasOutstandingCredit: Bool
    var game: Game?

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        seatOrder: Int,
        isBankrupt: Bool = false,
        hasOutstandingCredit: Bool = false
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.seatOrder = seatOrder
        self.isBankrupt = isBankrupt
        self.hasOutstandingCredit = hasOutstandingCredit
    }
}
