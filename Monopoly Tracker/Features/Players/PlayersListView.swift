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
        NavigationStack {
            List {
                ForEach(players) { player in
                    PlayerRowView(
                        player: player,
                        balance: balance(for: player)
                    )
                }
                .onDelete(perform: deletePlayers)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Игроки")
        }
    }

    private func balance(for player: Player) -> Money {
        let id = player.id
        return allTransactions.reduce(Money.zero) { partial, txn in
            partial + txn.signedAmount(for: id)
        }
    }

    private func deletePlayers(at offsets: IndexSet) {
        for index in offsets {
            try? container.ledger.removePlayer(players[index])
        }
    }
}

private struct PlayerRowView: View {
    let player: Player
    let balance: Money

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
