import SwiftUI

struct NewGameView: View {
    @Environment(AppContainer.self) private var container

    @State private var startingBalance: Money = 1500
    @State private var playerNames: [String] = ["", ""]
    @FocusState private var focusedField: Int?
    @State private var error: LedgerError?

    private static let presets: [Money] = [500, 1000, 1500, 2500, 5000]

    var body: some View {
        NavigationStack {
            Form {
                balanceSection
                playersSection
                startSection
            }
            .navigationTitle("Новая игра")
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                "Не получилось начать игру",
                isPresented: errorBinding,
                presenting: error
            ) { _ in
                Button("OK", role: .cancel) { error = nil }
            } message: { error in
                Text(error.errorDescription ?? "Неизвестная ошибка")
            }
        }
    }

    private var balanceSection: some View {
        Section("Стартовый баланс") {
            HStack {
                Text(startingBalance, format: .monopolyMoney)
                    .font(.system(size: 24, weight: .light, design: .monospaced))
                    .contentTransition(.numericText())
                Spacer()
            }
            .padding(.vertical, 4)

            Picker("Сумма", selection: $startingBalance) {
                ForEach(Self.presets, id: \.self) { value in
                    Text(value, format: .monopolyMoney).tag(value)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var playersSection: some View {
        Section("Игроки") {
            ForEach(playerNames.indices, id: \.self) { index in
                HStack(spacing: 12) {
                    PlayerColorSwatch(seat: index)
                    TextField("Имя игрока \(index + 1)", text: $playerNames[index])
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: index)
                    if playerNames.count > 2 {
                        Button(role: .destructive) {
                            removePlayer(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Удалить игрока \(index + 1)")
                    }
                }
            }

            Button {
                addPlayer()
            } label: {
                Label("Добавить игрока", systemImage: "plus.circle")
            }
            .disabled(playerNames.count >= 8)
        }
    }

    @ViewBuilder
    private var startSection: some View {
        Section {
            Button(action: start) {
                Text("Начать игру")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .disabled(!canStart)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } footer: {
            if let hint = disabledReason {
                Text(hint)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var canStart: Bool {
        disabledReason == nil
    }

    private var disabledReason: String? {
        let trimmed = playerNames.map { $0.trimmingCharacters(in: .whitespaces) }
        let nonEmpty = trimmed.filter { !$0.isEmpty }

        if nonEmpty.count < 2 {
            return String(localized: "Заполните минимум двух игроков, чтобы начать.")
        }
        if nonEmpty.count != trimmed.count {
            return String(localized: "Уберите пустые поля или заполните все имена.")
        }
        return nil
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )
    }

    private func addPlayer() {
        playerNames.append("")
        focusedField = playerNames.count - 1
    }

    private func removePlayer(at index: Int) {
        playerNames.remove(at: index)
    }

    private func start() {
        focusedField = nil
        do {
            try container.ledger.startGame(
                playerNames: playerNames,
                startingBalance: startingBalance
            )
        } catch let ledgerError as LedgerError {
            error = ledgerError
        } catch {
            self.error = .missingPlayer
        }
    }
}

private struct PlayerColorSwatch: View {
    let seat: Int

    var body: some View {
        Circle()
            .fill(Color(hex: LiveLedgerService.defaultColorHex(forSeat: seat)))
            .frame(width: 20, height: 20)
            .overlay(
                Circle().strokeBorder(.separator, lineWidth: 0.5)
            )
    }
}
