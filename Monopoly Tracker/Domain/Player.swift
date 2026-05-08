import Foundation
import SwiftData

@Model
final class Player {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var seatOrder: Int
    var game: Game?

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        seatOrder: Int
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.seatOrder = seatOrder
    }
}
