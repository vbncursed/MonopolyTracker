import Foundation
import SwiftData

@Model
final class Transaction {
    #Index<Transaction>(
        [\.timestamp],
        [\.fromPlayerID],
        [\.toPlayerID]
    )

    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var amount: Money
    var kindRaw: String

    /// Денормализовано: ID и имя сохраняются на момент записи. Если игрок будет
    /// удалён позже, история останется читаемой. nil = банк.
    var fromPlayerID: UUID?
    var fromPlayerName: String?
    var toPlayerID: UUID?
    var toPlayerName: String?

    var note: String?
    var game: Game?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        amount: Money,
        kind: TransactionKind,
        from: Player?,
        to: Player?,
        note: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.amount = amount
        self.kindRaw = kind.rawValue
        self.fromPlayerID = from?.id
        self.fromPlayerName = from?.name
        self.toPlayerID = to?.id
        self.toPlayerName = to?.name
        self.note = note
    }

    var kind: TransactionKind {
        TransactionKind(rawValue: kindRaw) ?? .custom
    }

    /// Знак с точки зрения игрока: положительный — пришли деньги, отрицательный — ушли.
    func signedAmount(for playerID: UUID) -> Money {
        var delta: Money = .zero
        if toPlayerID == playerID { delta += amount }
        if fromPlayerID == playerID { delta -= amount }
        return delta
    }
}
