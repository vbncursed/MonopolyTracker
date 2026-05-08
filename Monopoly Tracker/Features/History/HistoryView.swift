import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(
        filter: #Predicate<Transaction> { $0.game?.endedAt == nil },
        sort: \Transaction.timestamp,
        order: .reverse
    )
    private var transactions: [Transaction]

    var body: some View {
        NavigationStack {
            List {
                ForEach(transactions) { txn in
                    TransactionRowView(transaction: txn)
                }
            }
            .listStyle(.plain)
            .navigationTitle("История")
            .overlay {
                if transactions.isEmpty {
                    ContentUnavailableView(
                        "История пуста",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Сделайте первый перевод во вкладке «Перевод».")
                    )
                }
            }
        }
    }
}

private struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.kind.systemImageName)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.system(size: 15))
                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(transaction.timestamp, format: .dateTime.day().month().hour().minute())
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(transaction.amount, format: .monopolyMoney)
                .font(.system(size: 15, weight: .light, design: .monospaced))
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private var headline: String {
        let from = transaction.fromPlayerName ?? "Банк"
        let to = transaction.toPlayerName ?? "Банк"
        return "\(from) → \(to)"
    }
}
