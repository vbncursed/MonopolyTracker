import SwiftData
import SwiftUI

/// Показывает форму перевода, если игра идёт; иначе — заглушку.
struct TransferOrEmptyView: View {
    @Query(filter: #Predicate<Game> { $0.endedAt == nil })
    private var activeGames: [Game]

    var body: some View {
        if activeGames.isEmpty {
            NavigationStack {
                ContentUnavailableView(
                    "Игра не идёт",
                    systemImage: "arrow.left.arrow.right",
                    description: Text("Начните новую игру во вкладке «Игра», чтобы делать переводы.")
                )
                .navigationTitle("Перевод")
                .navigationBarTitleDisplayMode(.inline)
            }
        } else {
            TransferView()
        }
    }
}
