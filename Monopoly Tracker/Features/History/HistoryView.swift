import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(AppContainer.self) private var container
    @Query(
        filter: #Predicate<Transaction> { $0.game?.endedAt == nil },
        sort: \Transaction.timestamp,
        order: .reverse
    )
    private var transactions: [Transaction]

    @State private var reverseError: LedgerError?

    var body: some View {
        NavigationStack {
            List {
                ForEach(transactions) { txn in
                    TransactionRowView(transaction: txn)
                        .swipeActions(edge: .trailing) {
                            if txn.kind != .gameStart && txn.kind != .reversal {
                                Button("Отменить", systemImage: "arrow.uturn.backward") {
                                    reverse(txn)
                                }
                                .tint(.orange)
                            }
                        }
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
            .alert(
                "Не удалось отменить",
                isPresented: reverseErrorBinding,
                presenting: reverseError
            ) { _ in
                Button("OK", role: .cancel) { reverseError = nil }
            } message: { error in
                Text(error.errorDescription ?? "")
            }
        }
    }

    private var reverseErrorBinding: Binding<Bool> {
        Binding(
            get: { reverseError != nil },
            set: { if !$0 { reverseError = nil } }
        )
    }

    private func reverse(_ txn: Transaction) {
        do {
            try container.ledger.reverseTransaction(txn)
        } catch let error as LedgerError {
            reverseError = error
        } catch {
            reverseError = .missingPlayer
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
                Text(timestampLabel)
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

    /// «5 минут назад» для свежих транзакций, «8 May 14:23» для давних.
    /// Порог — 24 часа: внутри — относительный формат, снаружи — абсолютный.
    private var timestampLabel: String {
        let interval = Date.now.timeIntervalSince(transaction.timestamp)
        if interval < 60 * 60 * 24 {
            return transaction.timestamp.formatted(.relative(presentation: .numeric))
        }
        return transaction.timestamp.formatted(.dateTime.day().month().hour().minute())
    }
}
