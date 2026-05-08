import Foundation
import SwiftData

@Model
final class Player {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var seatOrder: Int
    var createdAt: Date
    var game: Game?

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        seatOrder: Int,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.seatOrder = seatOrder
        self.createdAt = createdAt
    }
}
