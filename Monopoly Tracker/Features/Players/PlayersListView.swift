import SwiftData
import SwiftUI

struct PlayersListView: View {
    @Environment(AppContainer.self) private var container
    @Query(
        filter: #Predicate<Player> { $0.game?.endedAt == nil },
        sort: \Player.seatOrder
    )
    private var players: [Player]
    @Query(filter: #Predicate<Transaction> { $0.game?.endedAt == nil })
    private var allTransactions: [Transaction]
    @Query(filter: #Predicate<Game> { $0.endedAt == nil })
    private var activeGames: [Game]

    var body: some View {
        if activeGames.isEmpty {
            NewGameView()
        } else {
            playersScreen
        }
    }

    private var playersScreen: some View {
        let balances = makeBalances()
        return NavigationStack {
            List {
                ForEach(players) { player in
                    PlayerRowView(
                        player: player,
                        balance: balances[player.id, default: 0]
                    )
                    .swipeActions(edge: .leading) {
                        if !player.isBankrupt && !player.hasOutstandingCredit {
                            Button("Кредит", systemImage: "creditcard") {
                                try? container.ledger.takeCredit(player)
                            }
                            .tint(.blue)
                        }
                        if !player.isBankrupt && player.hasOutstandingCredit {
                            Button("Вернуть кредит", systemImage: "creditcard.fill") {
                                try? container.ledger.repayCredit(player)
                            }
                            .tint(.green)
                        }
                    }
                }
                .onDelete(perform: deletePlayers)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Игроки")
        }
    }

    /// Один O(N) проход по транзакциям активной игры → словарь playerID → balance.
    /// Раньше каждая строка делала свой reduce, итого O(N×M). Теперь O(N+M).
    private func makeBalances() -> [UUID: Money] {
        var map: [UUID: Money] = [:]
        for txn in allTransactions {
            if let from = txn.fromPlayerID {
                map[from, default: 0] -= txn.amount
            }
            if let to = txn.toPlayerID {
                map[to, default: 0] += txn.amount
            }
        }
        return map
    }

    private func deletePlayers(at offsets: IndexSet) {
        for index in offsets {
            try? container.ledger.removePlayer(players[index])
        }
    }
}

private struct PlayerRowView: View, Equatable {
    let player: Player
    let balance: Money

    static func == (lhs: PlayerRowView, rhs: PlayerRowView) -> Bool {
        lhs.player.id == rhs.player.id
            && lhs.player.name == rhs.player.name
            && lhs.player.colorHex == rhs.player.colorHex
            && lhs.player.seatOrder == rhs.player.seatOrder
            && lhs.player.isBankrupt == rhs.player.isBankrupt
            && lhs.player.hasOutstandingCredit == rhs.player.hasOutstandingCredit
            && lhs.balance == rhs.balance
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: player.colorHex))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(initial)
                        .font(.system(.footnote, weight: .medium))
                        .foregroundStyle(.white)
                )
                .opacity(player.isBankrupt ? 0.4 : 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(player.name)
                        .font(.body)
                        .foregroundStyle(player.isBankrupt ? .secondary : .primary)
                        .strikethrough(player.isBankrupt)
                    if player.hasOutstandingCredit {
                        Image(systemName: "creditcard.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .accessibilityLabel("Открыт кредит")
                    }
                }
                if player.isBankrupt {
                    Text("Банкрот")
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else {
                    Text("Место \(player.seatOrder + 1)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(balance.formatted(.monopolyMoney))
                .font(.system(.body, design: .monospaced).weight(.light))
                .foregroundStyle(balance < 0 ? Color.red : Color.primary)
                .contentTransition(.numericText(value: NSDecimalNumber(decimal: balance).doubleValue))
                .monospacedDigit()
                .accessibilityLabel("Баланс \(player.name): \(balance.formatted(.monopolyMoney))")
        }
        .padding(.vertical, 4)
    }

    private var initial: String {
        String(player.name.prefix(1)).uppercased()
    }
}
