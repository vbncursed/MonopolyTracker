import SwiftData
import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Игра", systemImage: "person.3") {
                PlayersListView()
            }
            Tab("Перевод", systemImage: "arrow.left.arrow.right") {
                TransferOrEmptyView()
            }
            Tab("История", systemImage: "list.bullet.rectangle") {
                HistoryView()
            }
            Tab("Настройки", systemImage: "gearshape") {
                GameSettingsView()
            }
        }
    }
}
