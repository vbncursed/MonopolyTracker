import SwiftData
import SwiftUI

struct TransferView: View {
    @Environment(AppContainer.self) private var container
    @Query(sort: \Player.seatOrder) private var players: [Player]

    @State private var viewModel: TransferViewModel?
    @State private var amountText: String = ""
    @FocusState private var amountFieldFocused: Bool

    private static let quickAmounts: [Money] = [50, 100, 200, 500, 1000]

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    form(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Перевод")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            if viewModel == nil {
                viewModel = TransferViewModel(
                    ledger: container.ledger,
                    resolvePlayer: { [players] id in
                        players.first(where: { $0.id == id })
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func form(viewModel: TransferViewModel) -> some View {
        @Bindable var bindable = viewModel

        Form {
            Section("Откуда") {
                PartyPicker(selection: $bindable.from, players: players)
            }

            Section {
                Button {
                    viewModel.swapParties()
                } label: {
                    Label("Поменять местами", systemImage: "arrow.up.arrow.down")
                }
                .frame(maxWidth: .infinity)
            }

            Section("Куда") {
                PartyPicker(selection: $bindable.to, players: players)
            }

            Section("Сумма") {
                TextField("0", text: $amountText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 32, weight: .light, design: .monospaced))
                    .focused($amountFieldFocused)
                    .onChange(of: amountText) { _, newValue in
                        viewModel.amount = Money(string: newValue) ?? 0
                    }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.quickAmounts, id: \.self) { value in
                            Button {
                                let next = (viewModel.amount) + value
                                amountText = next.plainString
                                viewModel.amount = next
                            } label: {
                                Text("+" + value.formatted(.monopolyMoney))
                            }
                            .buttonStyle(.glass)
                        }
                        Button(role: .destructive) {
                            amountText = ""
                            viewModel.amount = 0
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.glass)
                    }
                }
            }

            Section("Назначение") {
                Picker("Тип", selection: $bindable.kind) {
                    ForEach(TransactionKind.allCases, id: \.self) { kind in
                        Label(kind.displayName, systemImage: kind.systemImageName)
                            .tag(kind)
                    }
                }
                TextField("Комментарий (необязательно)", text: $bindable.note, axis: .vertical)
                    .lineLimit(1...3)
            }

            Section {
                Button {
                    viewModel.submit()
                    if viewModel.didSucceed {
                        amountText = ""
                        amountFieldFocused = false
                    }
                } label: {
                    Text("Перевести")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(!viewModel.canSubmit)
            }
        }
        .alert(
            "Ошибка перевода",
            isPresented: errorBinding(viewModel: viewModel),
            presenting: viewModel.lastError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.errorDescription ?? "")
        }
    }

    private func errorBinding(viewModel: TransferViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.lastError != nil },
            set: { if !$0 { viewModel.clearError() } }
        )
    }
}

private struct PartyPicker: View {
    @Binding var selection: TransferParty
    let players: [Player]

    var body: some View {
        Picker("Сторона", selection: $selection) {
            Label("Банк", systemImage: "building.columns").tag(TransferParty.bank)
            ForEach(players) { player in
                Label {
                    Text(player.name)
                } icon: {
                    Circle().fill(Color(hex: player.colorHex))
                }
                .tag(TransferParty.player(player.id))
            }
        }
        .pickerStyle(.menu)
    }
}

private extension Money {
    init?(string: String) {
        let cleaned = string.filter { $0.isNumber || $0 == "." || $0 == "," }
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Decimal(string: cleaned) else { return nil }
        self = value
    }

    var plainString: String {
        var value = self
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return NSDecimalNumber(decimal: rounded).stringValue
    }
}
