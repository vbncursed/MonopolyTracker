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

    /// Создаёт компенсирующую транзакцию (`.reversal`), отменяющую денежный
    /// эффект `original`. Журнал не модифицируется — `original` остаётся,
    /// добавляется новая запись с обратным направлением и тем же amount.
    /// Стартовую раздачу (`gameStart`) отменить нельзя — это сломало бы
    /// инвариант стартового баланса.
    func reverseTransaction(_ original: Transaction) throws

    /// Выдаёт игроку кредит: `monopolyCreditPrincipal` уходит на счёт от банка,
    /// флаг `hasOutstandingCredit` поднимается. Игрок обязан вернуть
    /// `monopolyCreditRepayment`. Нельзя взять второй кредит до возврата первого
    /// и нельзя кредитовать банкрота.
    func takeCredit(_ player: Player) throws

    /// Возврат кредита: `monopolyCreditRepayment` уходит со счёта в банк,
    /// флаг сбрасывается. Доступно только если кредит был взят.
    func repayCredit(_ player: Player) throws
}

/// Максимальное число игроков в одной партии. Соответствует UI-капу в `NewGameView`.
let monopolyMaxPlayers = 8

/// Порог банкротства: баланс ниже этого значения переводит игрока в `.isBankrupt`.
let monopolyBankruptcyFloor: Money = -5_000

/// Сумма, которую игрок получает на счёт при выдаче кредита.
let monopolyCreditPrincipal: Money = 5_000

/// Сумма, которую игрок обязан вернуть в банк при погашении кредита (комиссия 500).
let monopolyCreditRepayment: Money = 5_500
