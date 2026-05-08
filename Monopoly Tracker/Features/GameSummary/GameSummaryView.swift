import SwiftData
import SwiftUI

/// Итоговая сводка партии: ранжированные балансы, корона у победителя.
/// Показывается из настроек перед сбросом — пользователь видит, чем кончилось,
/// и подтверждает завершение.
struct GameSummaryView: View {
    let game: Game
    let onConfirmReset: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var ranking: [(player: Player, balance: Money)] {
        let balances = makeBalances()
        return game.players
            .map { ($0, balances[$0.id, default: 0]) }
            .sorted { $0.1 > $1.1 }
    }

    private func makeBalances() -> [UUID: Money] {
        var map: [UUID: Money] = [:]
        for txn in game.transactions {
            if let from = txn.fromPlayerID {
                map[from, default: 0] -= txn.amount
            }
            if let to = txn.toPlayerID {
                map[to, default: 0] += txn.amount
            }
        }
        return map
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(ranking.enumerated()), id: \.element.player.id) { index, entry in
                        SummaryRowView(
                            position: index + 1,
                            player: entry.player,
                            balance: entry.balance,
                            isWinner: index == 0
                        )
                    }
                } header: {
                    Text("Итог")
                } footer: {
                    Text("После завершения история этой игры останется в базе, но скроется из UI до начала новой партии.")
                }
            }
            .navigationTitle("Игра окончена")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Прибитая снизу кнопка — большая, glass-prominent, всегда видна
                // независимо от detent'а sheet'а и длины списка игроков.
                Button(role: .destructive) {
                    onConfirmReset()
                    dismiss()
                } label: {
                    Label("Завершить игру", systemImage: "flag.checkered")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.bar)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct SummaryRowView: View {
    let position: Int
    let player: Player
    let balance: Money
    let isWinner: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: player.colorHex))
                    .frame(width: 32, height: 32)
                if isWinner {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .offset(x: 14, y: -14)
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.body)
                    .fontWeight(isWinner ? .semibold : .regular)
                Text("\(position) место")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(balance.formatted(.monopolyMoney))
                .font(.system(.body, design: .monospaced).weight(.light))
                .foregroundStyle(balance < 0 ? Color.red : Color.primary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}
