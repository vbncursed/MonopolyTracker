import Foundation
import SwiftData
import Testing
@testable import Monopoly_Tracker

@MainActor
struct LedgerServiceTests {
    private static func makeService() throws -> LiveLedgerService {
        let schema = Schema([Game.self, Player.self, Transaction.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return LiveLedgerService(container: container)
    }

    @Test func startGame_seedsOpeningTransactions() async throws {
        let service = try Self.makeService()

        let game = try service.startGame(
            playerNames: ["Alice", "Bob"],
            startingBalance: 1500
        )

        #expect(game.players.count == 2)
        #expect(game.transactions.count == 2)
        for player in game.players {
            let balance = try service.balance(of: player)
            #expect(balance == 1500)
        }
    }

    @Test func startGame_rejectsFewerThanTwoPlayers() async throws {
        let service = try Self.makeService()

        #expect(throws: LedgerError.tooFewPlayers) {
            try service.startGame(playerNames: ["Solo"], startingBalance: 1500)
        }
    }

    @Test func startGame_allowsDuplicateNames() async throws {
        // В реальной Монополии могут играть два «Саши» — игроки идентифицируются
        // по UUID, имя — лишь подпись. Сервис не должен запрещать одинаковые имена.
        let service = try Self.makeService()

        let game = try service.startGame(
            playerNames: ["Саша", "Саша"],
            startingBalance: 1500
        )

        #expect(game.players.count == 2)
        #expect(Set(game.players.map(\.id)).count == 2, "У одинаковых имён должны быть разные id")
    }

    @Test func transfer_movesMoneyBetweenPlayers() async throws {
        let service = try Self.makeService()
        let game = try service.startGame(
            playerNames: ["Alice", "Bob"],
            startingBalance: 1500
        )
        let alice = try #require(game.players.first(where: { $0.name == "Alice" }))
        let bob = try #require(game.players.first(where: { $0.name == "Bob" }))

        try service.record(amount: 200, kind: .transfer, from: alice, to: bob, note: nil)

        #expect(try service.balance(of: alice) == 1300)
        #expect(try service.balance(of: bob) == 1700)
    }

    @Test func bankPayout_increasesPlayerBalance() async throws {
        let service = try Self.makeService()
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 1500)
        let alice = try #require(game.players.first)

        try service.record(amount: 200, kind: .salary, from: nil, to: alice, note: "Прошёл «Старт»")

        #expect(try service.balance(of: alice) == 1700)
    }

    @Test func goingNegative_withoutCredit_marksBankrupt() async throws {
        // Без открытого кредита любой минус — банкротство.
        let service = try Self.makeService()
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 100)
        let alice = try #require(game.players.first(where: { $0.name == "A" }))
        let bob = try #require(game.players.first(where: { $0.name == "B" }))

        try service.record(amount: 500, kind: .transfer, from: alice, to: bob, note: nil)

        #expect(try service.balance(of: alice) == -400)
        #expect(alice.isBankrupt, "Минус без кредита → банкрот")
        #expect(try service.balance(of: bob) == 600)
    }

    @Test func creditAllowsBalanceDownTo_neg5000_withoutBankruptcy() async throws {
        // С открытым кредитом игрок может уйти в минус — но не глубже -5000.
        let service = try Self.makeService()
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 100)
        let alice = try #require(game.players.first(where: { $0.name == "A" }))
        let bob = try #require(game.players.first(where: { $0.name == "B" }))

        try service.takeCredit(alice)
        // alice: 100 + 5000 = 5100
        try service.record(amount: 10_000, kind: .transfer, from: alice, to: bob, note: nil)
        // alice: 5100 - 10000 = -4900 (на 100 не доходит до пола -5000)

        #expect(try service.balance(of: alice) == -4_900)
        #expect(!alice.isBankrupt, "С кредитом -4900 ещё в пределах допустимого минуса")
    }

    @Test func belowMinus5000_withCredit_marksBankrupt() async throws {
        let service = try Self.makeService()
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 100)
        let alice = try #require(game.players.first(where: { $0.name == "A" }))
        let bob = try #require(game.players.first(where: { $0.name == "B" }))

        try service.takeCredit(alice)
        try service.record(amount: 10_500, kind: .transfer, from: alice, to: bob, note: nil)
        // alice: 5100 - 10500 = -5400, ниже -5000 → банкрот

        #expect(alice.isBankrupt)
    }

    @Test func repayingCreditIntoNegative_marksBankrupt() async throws {
        // Возврат кредита может загнать в минус без кредита — мгновенный банкрот.
        let service = try Self.makeService()
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 100)
        let alice = try #require(game.players.first(where: { $0.name == "A" }))
        let bob = try #require(game.players.first(where: { $0.name == "B" }))

        try service.takeCredit(alice)              // 100 + 5000 = 5100
        try service.record(amount: 5_000, kind: .transfer, from: alice, to: bob, note: nil)
        // alice = 100, кредит висит
        try service.repayCredit(alice)
        // alice = 100 - 5500 = -5400, кредит сброшен → пол стал 0 → банкрот

        #expect(alice.isBankrupt)
    }

    @Test func transfer_rejectsZeroAmount() async throws {
        let service = try Self.makeService()
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 100)
        let alice = try #require(game.players.first)

        #expect(throws: LedgerError.nonPositiveAmount) {
            try service.record(amount: 0, kind: .transfer, from: alice, to: nil, note: nil)
        }
    }

    @Test func transfer_rejectsSelfTransfer() async throws {
        let service = try Self.makeService()
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 100)
        let alice = try #require(game.players.first)

        #expect(throws: LedgerError.selfTransfer) {
            try service.record(amount: 50, kind: .transfer, from: alice, to: alice, note: nil)
        }
    }

    @Test func transfer_rejectsBankToBank() async throws {
        let service = try Self.makeService()
        _ = try service.startGame(playerNames: ["A", "B"], startingBalance: 100)

        #expect(throws: LedgerError.bankToBank) {
            try service.record(amount: 50, kind: .transfer, from: nil, to: nil, note: nil)
        }
    }

    @Test func addPlayer_extendsRosterAndSeedsOpeningTransaction() async throws {
        let service = try Self.makeService()
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 1500)

        let charlie = try service.addPlayer(name: "C", colorHex: "#000000")

        #expect(game.players.count == 3)
        #expect(charlie.seatOrder == 2)
        #expect(try service.balance(of: charlie) == 1500, "Новому игроку выдан стартовый баланс")
    }

    @Test func removePlayer_dropsRosterEntry_keepsHistoryReadable() async throws {
        let service = try Self.makeService()
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 100)
        let alice = try #require(game.players.first(where: { $0.name == "A" }))
        let bob = try #require(game.players.first(where: { $0.name == "B" }))

        try service.record(amount: 50, kind: .transfer, from: alice, to: bob, note: nil)
        try service.removePlayer(alice)

        #expect(game.players.count == 1)
        // Транзакция остаётся в журнале, имя денормализовано.
        let txns = game.transactions.filter { $0.kind == .transfer }
        #expect(txns.count == 1)
        #expect(txns.first?.fromPlayerName == "A")
    }

    @Test func startGame_rejectsMoreThanEightPlayers() async throws {
        let service = try Self.makeService()
        let nine = (1...9).map { "P\($0)" }

        #expect(throws: LedgerError.tooManyPlayers) {
            try service.startGame(playerNames: nine, startingBalance: 1500)
        }
    }

    @Test func addPlayer_rejectedWhenRosterFull() async throws {
        let service = try Self.makeService()
        let names = (1...8).map { "P\($0)" }
        _ = try service.startGame(playerNames: names, startingBalance: 1500)

        #expect(throws: LedgerError.tooManyPlayers) {
            try service.addPlayer(name: "P9", colorHex: "#000000")
        }
    }

    @Test func reverseTransaction_inverts_andLeavesOriginalIntact() async throws {
        let service = try Self.makeService()
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 1500)
        let alice = try #require(game.players.first(where: { $0.name == "A" }))
        let bob = try #require(game.players.first(where: { $0.name == "B" }))

        try service.record(amount: 200, kind: .transfer, from: alice, to: bob, note: nil)
        let original = try #require(game.transactions.first(where: { $0.kind == .transfer }))

        try service.reverseTransaction(original)

        #expect(try service.balance(of: alice) == 1500, "Алиса вернулась к стартовому балансу")
        #expect(try service.balance(of: bob) == 1500, "Боб вернулся к стартовому балансу")
        let reversals = game.transactions.filter { $0.kind == .reversal }
        #expect(reversals.count == 1)
        #expect(reversals.first?.fromPlayerID == bob.id, "У реверсала направление инвертировано")
        #expect(reversals.first?.toPlayerID == alice.id)
    }

    @Test func reverseTransaction_rejectsGameStart() async throws {
        let service = try Self.makeService()
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 1500)
        let opening = try #require(game.transactions.first(where: { $0.kind == .gameStart }))

        #expect(throws: LedgerError.cannotReverseOpening) {
            try service.reverseTransaction(opening)
        }
    }

    @Test func takeCredit_addsPrincipalToBalance() async throws {
        let service = try Self.makeService()
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 1500)
        let alice = try #require(game.players.first(where: { $0.name == "A" }))

        try service.takeCredit(alice)

        #expect(alice.hasOutstandingCredit)
        #expect(try service.balance(of: alice) == 1500 + monopolyCreditPrincipal)
    }

    @Test func takeCredit_secondTimeFails() async throws {
        let service = try Self.makeService()
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 1500)
        let alice = try #require(game.players.first(where: { $0.name == "A" }))

        try service.takeCredit(alice)

        #expect(throws: LedgerError.creditAlreadyOutstanding) {
            try service.takeCredit(alice)
        }
    }

    @Test func repayCredit_chargesInterest_andClearsFlag() async throws {
        let service = try Self.makeService()
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 1500)
        let alice = try #require(game.players.first(where: { $0.name == "A" }))

        try service.takeCredit(alice)
        // 1500 + 5000 = 6500
        try service.repayCredit(alice)
        // 6500 - 5500 = 1000 (комиссия 500 ушла банку).

        #expect(!alice.hasOutstandingCredit)
        #expect(try service.balance(of: alice) == 1000)
    }

    @Test func repayCredit_withoutOutstandingFails() async throws {
        let service = try Self.makeService()
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 1500)
        let alice = try #require(game.players.first(where: { $0.name == "A" }))

        #expect(throws: LedgerError.noCreditOutstanding) {
            try service.repayCredit(alice)
        }
    }

    @Test func bankruptcyOnlyAffectsThePayer_notRecipient() async throws {
        let service = try Self.makeService()
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 100)
        let alice = try #require(game.players.first(where: { $0.name == "A" }))
        let bob = try #require(game.players.first(where: { $0.name == "B" }))

        try service.record(amount: 6_000, kind: .transfer, from: alice, to: bob, note: nil)

        #expect(alice.isBankrupt, "Плательщик ушёл в минус → банкрот")
        #expect(!bob.isBankrupt, "Получатель остался платёжеспособным")
    }

    @Test func bankruptPlayer_cannotParticipateInTransfers() async throws {
        let service = try Self.makeService()
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 100)
        let alice = try #require(game.players.first(where: { $0.name == "A" }))
        let bob = try #require(game.players.first(where: { $0.name == "B" }))

        try service.record(amount: 6_000, kind: .transfer, from: alice, to: bob, note: nil)
        #expect(alice.isBankrupt)

        // Банкрот не может ни платить, ни получать.
        #expect(throws: LedgerError.playerBankrupt) {
            try service.record(amount: 50, kind: .transfer, from: alice, to: bob, note: nil)
        }
        #expect(throws: LedgerError.playerBankrupt) {
            try service.record(amount: 50, kind: .transfer, from: bob, to: alice, note: nil)
        }
        #expect(throws: LedgerError.playerBankrupt) {
            try service.takeCredit(alice)
        }
    }

    @Test func endActiveGame_preservesHistory() async throws {
        let service = try Self.makeService()
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 100)
        let alice = try #require(game.players.first)
        try service.record(amount: 30, kind: .transfer, from: alice, to: nil, note: nil)

        try service.endActiveGame()

        #expect(try service.activeGame() == nil)
        #expect(game.endedAt != nil)
        #expect(game.transactions.count == 3)
    }

    @Test func balanceInvariant_sumOverPlayersEqualsSumOfStartingBalances() async throws {
        let service = try Self.makeService()
        let game = try service.startGame(
            playerNames: ["A", "B", "C"],
            startingBalance: 1500
        )
        let players = game.players
        let alice = try #require(players.first(where: { $0.name == "A" }))
        let bob = try #require(players.first(where: { $0.name == "B" }))
        let carol = try #require(players.first(where: { $0.name == "C" }))

        // Произвольные движения внутри игроков (банк не трогаем).
        try service.record(amount: 200, kind: .transfer, from: alice, to: bob, note: nil)
        try service.record(amount: 50, kind: .rent, from: carol, to: alice, note: nil)
        try service.record(amount: 75, kind: .fee, from: bob, to: carol, note: nil)

        let total = try players.reduce(Decimal.zero) { partial, player in
            partial + (try service.balance(of: player))
        }
        let expected = Money(players.count) * game.startingBalance
        #expect(total == expected, "Сумма по игрокам должна сохраняться при переводах между ними")
    }
}

@MainActor
struct TransferViewModelTests {
    private static func setup() throws -> (vm: TransferViewModel, players: [Player], service: LiveLedgerService) {
        let schema = Schema([Game.self, Player.self, Transaction.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let service = LiveLedgerService(container: container)
        let game = try service.startGame(playerNames: ["A", "B"], startingBalance: 1500)
        let players = game.players
        let viewModel = TransferViewModel(
            ledger: service,
            resolvePlayer: { id in players.first(where: { $0.id == id }) }
        )
        return (viewModel, players, service)
    }

    @Test func canSubmit_requiresPositiveAmountAndDifferentParties() async throws {
        let (vm, players, _) = try Self.setup()
        let alice = try #require(players.first)

        #expect(!vm.canSubmit(amount: 0), "Старт: ноль сумма, обе стороны — банк")
        #expect(!vm.canSubmit(amount: 100), "Сумма есть, но from == to == банк")

        vm.from = .player(alice.id)
        #expect(vm.canSubmit(amount: 100), "Игрок → Банк должно быть валидным")

        vm.to = .player(alice.id)
        #expect(!vm.canSubmit(amount: 100), "Перевод самому себе невалиден")
    }

    @Test func submit_recordsAndResetsForm() async throws {
        let (vm, players, _) = try Self.setup()
        let alice = try #require(players.first(where: { $0.name == "A" }))
        let bob = try #require(players.first(where: { $0.name == "B" }))

        vm.from = .player(alice.id)
        vm.to = .player(bob.id)
        vm.note = "test"

        vm.submit(amount: 250)

        #expect(vm.didSucceed)
        #expect(vm.lastError == nil)
        #expect(vm.note.isEmpty, "Заметка сбрасывается после успеха")
    }

    @Test func submit_failurePathReportsError() async throws {
        let (vm, players, _) = try Self.setup()
        let alice = try #require(players.first)

        // 1) Обе стороны — банк, ненулевая сумма → bankToBank.
        vm.from = .bank
        vm.to = .bank
        vm.submit(amount: 100)
        #expect(!vm.didSucceed)
        #expect(vm.lastError == .bankToBank)

        // 2) Перевод самому себе.
        vm.clearError()
        vm.from = .player(alice.id)
        vm.to = .player(alice.id)
        vm.submit(amount: 50)
        #expect(!vm.didSucceed)
        #expect(vm.lastError == .selfTransfer)

        // 3) Нулевая сумма.
        vm.clearError()
        vm.from = .player(alice.id)
        vm.to = .bank
        vm.submit(amount: 0)
        #expect(!vm.didSucceed)
        #expect(vm.lastError == .nonPositiveAmount)
    }
}
