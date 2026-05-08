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

private struct TransactionRowView: View, Equatable {
    let transaction: Transaction

    static func == (lhs: TransactionRowView, rhs: TransactionRowView) -> Bool {
        lhs.transaction.id == rhs.transaction.id
            && lhs.transaction.amount == rhs.transaction.amount
            && lhs.transaction.kindRaw == rhs.transaction.kindRaw
            && lhs.transaction.note == rhs.transaction.note
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.kind.systemImageName)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.subheadline)
                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(transaction.timestamp, format: .dateTime.day().month().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(transaction.amount.formatted(.monopolyMoney))
                .font(.system(.subheadline, design: .monospaced).weight(.light))
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private var headline: String {
        let from = transaction.fromPlayerName ?? String(localized: "Банк")
        let to = transaction.toPlayerName ?? String(localized: "Банк")
        return "\(from) → \(to)"
    }
}
