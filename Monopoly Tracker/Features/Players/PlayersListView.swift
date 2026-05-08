import SwiftData
import SwiftUI

struct PlayersListView: View {
    @Environment(AppContainer.self) private var container
    @Query(sort: \Player.seatOrder) private var players: [Player]
    @Query private var allTransactions: [Transaction]
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
                        balance: balances[player.id, default: .zero]
                    )
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
                map[from, default: .zero] -= txn.amount
            }
            if let to = txn.toPlayerID {
                map[to, default: .zero] += txn.amount
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
            && lhs.balance == rhs.balance
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: player.colorHex))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(initial)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.system(size: 15, weight: .regular))
                Text("Место \(player.seatOrder + 1)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(balance, format: .monopolyMoney)
                .font(.system(size: 17, weight: .light, design: .monospaced))
                .foregroundStyle(balance < 0 ? Color.red : Color.primary)
                .contentTransition(.numericText(value: NSDecimalNumber(decimal: balance).doubleValue))
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private var initial: String {
        String(player.name.prefix(1)).uppercased()
    }
}
