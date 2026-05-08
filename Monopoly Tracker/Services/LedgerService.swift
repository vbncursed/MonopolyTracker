import Foundation

/// Единственная точка изменения денежного состояния игры.
/// Запись балансов напрямую в обход сервиса запрещена — иначе журнал и баланс разойдутся.
@MainActor
protocol LedgerService: AnyObject {
    /// Возвращает активную игру, если она есть.
    func activeGame() throws -> Game?

    /// Создаёт новую игру с указанным стартовым балансом и списком имён игроков.
    /// Завершает предыдущую активную игру, если она была.
    @discardableResult
    func startGame(playerNames: [String], startingBalance: Money) throws -> Game

    /// Завершает активную игру (ставит `endedAt`). История сохраняется.
    func endActiveGame() throws

    /// Регистрирует движение денег. nil в `from`/`to` означает банк.
    /// Овердрафт разрешён (реальная Монополия): сервис не блокирует переводы при нехватке средств.
    func record(
        amount: Money,
        kind: TransactionKind,
        from: Player?,
        to: Player?,
        note: String?
    ) throws

    /// Текущий баланс игрока в активной игре.
    /// Считается как стартовый баланс плюс сумма всех связанных транзакций.
    func balance(of player: Player) throws -> Money

    /// Добавляет нового игрока в активную игру со стартовым балансом игры.
    @discardableResult
    func addPlayer(name: String, colorHex: String) throws -> Player

    /// Удаляет игрока из активной игры. История транзакций сохраняется (имя денормализовано).
    func removePlayer(_ player: Player) throws
}
