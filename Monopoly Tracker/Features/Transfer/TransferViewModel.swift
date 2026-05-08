import Foundation

@MainActor
@Observable
final class TransferViewModel {
    var from: TransferParty = .bank
    var to: TransferParty = .bank
    var amount: Money = 0
    var kind: TransactionKind = .transfer
    var note: String = ""

    private(set) var lastError: LedgerError?
    private(set) var didSucceed: Bool = false

    private let ledger: LedgerService
    private let resolvePlayer: (UUID) -> Player?

    init(ledger: LedgerService, resolvePlayer: @escaping (UUID) -> Player?) {
        self.ledger = ledger
        self.resolvePlayer = resolvePlayer
    }

    var canSubmit: Bool {
        guard amount > 0 else { return false }
        if from == to { return false }
        if from.isBank && to.isBank { return false }
        return true
    }

    func clearError() {
        lastError = nil
    }

    func swapParties() {
        let saved = from
        from = to
        to = saved
    }

    func submit() {
        didSucceed = false
        lastError = nil

        let fromPlayer = playerFor(from)
        let toPlayer = playerFor(to)

        do {
            try ledger.record(
                amount: amount,
                kind: resolvedKind(),
                from: fromPlayer,
                to: toPlayer,
                note: note
            )
            didSucceed = true
            resetForNextTransfer()
        } catch let error as LedgerError {
            lastError = error
        } catch {
            lastError = .nonPositiveAmount
        }
    }

    private func playerFor(_ party: TransferParty) -> Player? {
        if case .player(let id) = party { return resolvePlayer(id) }
        return nil
    }

    /// Подменяет «Перевод» на более точный вид, когда одна сторона — банк.
    private func resolvedKind() -> TransactionKind {
        guard kind == .transfer else { return kind }
        switch (from.isBank, to.isBank) {
        case (true, false): return .bankPayout
        case (false, true): return .bankCollect
        default: return .transfer
        }
    }

    private func resetForNextTransfer() {
        amount = 0
        note = ""
        kind = .transfer
    }
}
