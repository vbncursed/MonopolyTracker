import Foundation
import SwiftData

@MainActor
final class LiveLedgerService: LedgerService {
    private let container: ModelContainer
    private let context: ModelContext

    init(container: ModelContainer) {
        self.container = container
        self.context = container.mainContext
    }

    func activeGame() throws -> Game? {
        let descriptor = FetchDescriptor<Game>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    @discardableResult
    func startGame(playerNames: [String], startingBalance: Money) throws -> Game {
        let trimmed = playerNames.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard trimmed.count >= 2 else { throw LedgerError.tooFewPlayers }
        guard trimmed.count <= monopolyMaxPlayers else { throw LedgerError.tooManyPlayers }

        try endActiveGameIfNeeded()

        let game = Game(startingBalance: startingBalance)
        context.insert(game)

        for (index, name) in trimmed.enumerated() {
            let player = Player(
                name: name,
                colorHex: Self.defaultColorHex(forSeat: index),
                seatOrder: index
            )
            player.game = game
            context.insert(player)

            let opening = Transaction(
                amount: startingBalance,
                kind: .gameStart,
                from: nil,
                to: player,
                note: nil
            )
            opening.game = game
            context.insert(opening)
        }

        try context.save()
        return game
    }

    func endActiveGame() throws {
        try endActiveGameIfNeeded()
        try context.save()
    }

    func record(
        amount: Money,
        kind: TransactionKind,
        from: Player?,
        to: Player?,
        note: String?
    ) throws {
        guard amount > 0 else { throw LedgerError.nonPositiveAmount }
        guard from != nil || to != nil else { throw LedgerError.bankToBank }
        if let from, let to, from.id == to.id { throw LedgerError.selfTransfer }
        if from?.isBankrupt == true || to?.isBankrupt == true {
            throw LedgerError.playerBankrupt
        }

        guard let game = try activeGame() else { throw LedgerError.noActiveGame }

        let txn = Transaction(
            amount: amount,
            kind: kind,
            from: from,
            to: to,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        txn.game = game
        context.insert(txn)
        try context.save()

        // После сохранения проверяем участников на банкротство —
        // если новый баланс ушёл ниже floor, помечаем флагом.
        try updateBankruptcyState(for: from)
        try updateBankruptcyState(for: to)
    }

    func balance(of player: Player) throws -> Money {
        let playerID = player.id
        // Скоупим до активной игры — иначе балансы могут утечь между играми,
        // если в БД есть архивные транзакции с тем же playerID.
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { txn in
                (txn.fromPlayerID == playerID || txn.toPlayerID == playerID)
                && txn.game?.endedAt == nil
            }
        )
        let txns = try context.fetch(descriptor)
        return txns.reduce(Decimal.zero) { partial, txn in
            partial + txn.signedAmount(for: playerID)
        }
    }

    @discardableResult
    func addPlayer(name: String, colorHex: String) throws -> Player {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw LedgerError.missingPlayer }

        guard let game = try activeGame() else { throw LedgerError.noActiveGame }
        guard game.players.count < monopolyMaxPlayers else { throw LedgerError.tooManyPlayers }

        let nextSeat = (game.players.map(\.seatOrder).max() ?? -1) + 1
        let player = Player(name: trimmed, colorHex: colorHex, seatOrder: nextSeat)
        player.game = game
        context.insert(player)

        let opening = Transaction(
            amount: game.startingBalance,
            kind: .gameStart,
            from: nil,
            to: player,
            note: nil
        )
        opening.game = game
        context.insert(opening)

        try context.save()
        return player
    }

    func removePlayer(_ player: Player) throws {
        context.delete(player)
        try context.save()
    }

    func takeCredit(_ player: Player) throws {
        guard !player.isBankrupt else { throw LedgerError.playerBankrupt }
        guard !player.hasOutstandingCredit else { throw LedgerError.creditAlreadyOutstanding }
        guard let game = try activeGame() else { throw LedgerError.noActiveGame }

        let credit = Transaction(
            amount: monopolyCreditPrincipal,
            kind: .credit,
            from: nil,
            to: player,
            note: nil
        )
        credit.game = game
        context.insert(credit)
        player.hasOutstandingCredit = true
        try context.save()
    }

    func repayCredit(_ player: Player) throws {
        guard !player.isBankrupt else { throw LedgerError.playerBankrupt }
        guard player.hasOutstandingCredit else { throw LedgerError.noCreditOutstanding }
        guard let game = try activeGame() else { throw LedgerError.noActiveGame }

        let repayment = Transaction(
            amount: monopolyCreditRepayment,
            kind: .creditRepay,
            from: player,
            to: nil,
            note: nil
        )
        repayment.game = game
        context.insert(repayment)
        player.hasOutstandingCredit = false
        try context.save()

        try updateBankruptcyState(for: player)
    }

    func reverseTransaction(_ original: Transaction) throws {
        guard original.kind != .gameStart else { throw LedgerError.cannotReverseOpening }
        guard let game = try activeGame() else { throw LedgerError.noActiveGame }

        // from реверсала = to оригинала, и наоборот. nil остаётся nil (банк).
        let reversedFromID = original.toPlayerID
        let reversedToID = original.fromPlayerID
        let reversedFromPlayer = reversedFromID.flatMap { id in
            game.players.first(where: { $0.id == id })
        }
        let reversedToPlayer = reversedToID.flatMap { id in
            game.players.first(where: { $0.id == id })
        }

        // Если оригинал ссылался на игрока, который удалён — Player object нет,
        // но имя денормализовано. Пишем reversal через сырой Transaction-init,
        // чтобы сохранить корректные имена даже без живого Player.
        let reversal = Transaction(
            id: UUID(),
            timestamp: .now,
            amount: original.amount,
            kind: .reversal,
            from: reversedFromPlayer,
            to: reversedToPlayer,
            note: String(localized: "Отмена транзакции")
        )
        // Денормализованные имена из оригинала (на случай удалённых игроков).
        reversal.fromPlayerID = reversedFromID
        reversal.fromPlayerName = original.toPlayerName
        reversal.toPlayerID = reversedToID
        reversal.toPlayerName = original.fromPlayerName
        reversal.game = game
        context.insert(reversal)
        try context.save()

        try updateBankruptcyState(for: reversedFromPlayer)
        try updateBankruptcyState(for: reversedToPlayer)
    }

    // MARK: - Helpers

    private func endActiveGameIfNeeded() throws {
        if let active = try activeGame() {
            active.endedAt = .now
        }
    }

    /// Помечает игрока банкротом, если его баланс ушёл ниже допустимого пола.
    /// Пол динамический:
    ///   - без кредита: пол = 0 (любой минус без кредита → банкрот);
    ///   - с открытым кредитом: пол = -5_000 (кредит даёт допуск ровно на 5k).
    /// Флаг банкротства необратим в рамках партии — в Монополии разорение
    /// окончательное.
    private func updateBankruptcyState(for player: Player?) throws {
        guard let player else { return }
        guard !player.isBankrupt else { return }
        let balance = try balance(of: player)
        let floor: Money = player.hasOutstandingCredit ? monopolyBankruptcyFloor : 0
        if balance < floor {
            player.isBankrupt = true
            try context.save()
        }
    }

    private static let palette: [String] = [
        "#E63946", "#1D3557", "#2A9D8F", "#F4A261",
        "#8338EC", "#06A77D", "#D62828", "#FFB703",
    ]

    static func defaultColorHex(forSeat seat: Int) -> String {
        palette[seat % palette.count]
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
