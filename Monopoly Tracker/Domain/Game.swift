import Foundation
import SwiftData

@Model
final class Game: Identifiable {
    #Index<Game>(
        [\.endedAt],
        [\.startedAt]
    )

    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var startingBalance: Money

    @Relationship(deleteRule: .cascade, inverse: \Player.game)
    var players: [Player] = []

    @Relationship(deleteRule: .cascade, inverse: \Transaction.game)
    var transactions: [Transaction] = []

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        startingBalance: Money
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = nil
        self.startingBalance = startingBalance
    }

    var isActive: Bool { endedAt == nil }
}
