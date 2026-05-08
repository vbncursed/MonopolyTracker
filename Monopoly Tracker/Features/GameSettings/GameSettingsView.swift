import SwiftData
import SwiftUI

struct GameSettingsView: View {
    @Environment(AppContainer.self) private var container
    @Query(filter: #Predicate<Game> { $0.endedAt == nil })
    private var activeGames: [Game]
    @Query private var allTransactions: [Transaction]

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("languageMode") private var languageMode: LanguageMode = .system

    @State private var showEndConfirmation: Bool = false
    @State private var newPlayerName: String = ""
    @State private var addPlayerError: LedgerError?

    private var activeGame: Game? { activeGames.first }

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                if let game = activeGame {
                    summarySection(for: game)
                    addPlayerSection
                    resetSection
                } else {
                    inactiveGameSection
                }
                aboutSection
            }
            .navigationTitle("Настройки")
            .alert("Сбросить игру?", isPresented: $showEndConfirmation) {
                Button("Сбросить", role: .destructive) {
                    try? container.ledger.endActiveGame()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Текущая игра завершится, история сохранится. Сразу после этого можно начать новую.")
            }
            .alert(
                "Не удалось добавить игрока",
                isPresented: addPlayerErrorBinding,
                presenting: addPlayerError
            ) { _ in
                Button("OK", role: .cancel) { addPlayerError = nil }
            } message: { error in
                Text(error.errorDescription ?? "")
            }
        }
    }

    private var appearanceSection: some View {
        Section("Оформление") {
            Picker(selection: $appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            } label: {
                Label("Тема", systemImage: "paintbrush")
            }
            .pickerStyle(.menu)

            Picker(selection: $languageMode) {
                ForEach(LanguageMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            } label: {
                Label("Язык", systemImage: "globe")
            }
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder
    private func summarySection(for game: Game) -> some View {
        Section("Текущая игра") {
            LabeledContent("Стартовый баланс") {
                Text(game.startingBalance, format: .monopolyMoney)
                    .monospacedDigit()
            }
            LabeledContent("Игроков") {
                Text(game.players.count, format: .number)
            }
            LabeledContent("Транзакций") {
                Text(allTransactions.count, format: .number)
            }
            LabeledContent("Начата") {
                Text(game.startedAt, format: .dateTime.day().month().year().hour().minute())
            }
        }
    }

    private var addPlayerSection: some View {
        Section("Добавить игрока") {
            HStack {
                TextField("Имя", text: $newPlayerName)
                    .textInputAutocapitalization(.words)
                Button("Добавить") {
                    addPlayer()
                }
                .buttonStyle(.glass)
                .disabled(newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                showEndConfirmation = true
            } label: {
                Label("Сбросить игру", systemImage: "arrow.counterclockwise")
            }
        } footer: {
            Text("Текущая игра завершится, журнал сохранится. После сброса вы сможете начать новую игру.")
        }
    }

    private var inactiveGameSection: some View {
        Section {
            ContentUnavailableView(
                "Игра не идёт",
                systemImage: "flag.checkered",
                description: Text("Сейчас активной игры нет — стартовый экран появится автоматически.")
            )
        }
    }

    private var aboutSection: some View {
        Section("О приложении") {
            LabeledContent("Версия") {
                Text(Self.versionString)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Сборка") {
                Text(Self.buildString)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private static var buildString: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private var addPlayerErrorBinding: Binding<Bool> {
        Binding(
            get: { addPlayerError != nil },
            set: { if !$0 { addPlayerError = nil } }
        )
    }

    private func addPlayer() {
        do {
            try container.ledger.addPlayer(
                name: newPlayerName,
                colorHex: LiveLedgerService.defaultColorHex(forSeat: (activeGame?.players.count ?? 0))
            )
            newPlayerName = ""
        } catch let error as LedgerError {
            addPlayerError = error
        } catch {
            addPlayerError = .missingPlayer
        }
    }
}
