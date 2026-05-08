import SwiftData
import SwiftUI
import UIKit

struct TransferView: View {
    @Environment(AppContainer.self) private var container
    @Query(
        filter: #Predicate<Player> { $0.game?.endedAt == nil && $0.isBankrupt == false },
        sort: \Player.seatOrder
    )
    private var players: [Player]

    @State private var viewModel: TransferViewModel?
    @State private var amountText: String = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case amount, note }

    private static let quickAmounts: [Money] = [50, 100, 200, 500, 1000]

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Перевод")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") { focusedField = nil }
                }
            }
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

    private var parsedAmount: Money {
        Money(parsing: amountText) ?? 0
    }

    /// Чистит ввод до цифр и форматирует через `.monopolyDigits` —
    /// получаем "1,500" вместо "1500" в реальном времени.
    private static func formatAmount(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty else { return "" }
        guard let value = Decimal(string: digits, locale: nil) else { return "" }
        return value.formatted(.monopolyDigits)
    }

    @ViewBuilder
    private func content(viewModel: TransferViewModel) -> some View {
        VStack(spacing: 0) {
            amountHero
            metaForm(viewModel: viewModel)
        }
        .sensoryFeedback(.success, trigger: viewModel.successCount)
        .sensoryFeedback(.error, trigger: viewModel.errorCount)
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

    /// Hero-зона ввода суммы. Намеренно живёт ВНЕ `Form` — иначе iOS-26-овский
    /// diffable layout `Form`-а пересчитывает все секции на каждое нажатие
    /// клавиши, и появляются заметные пролагивания.
    private var amountHero: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(verbatim: "$")
                        .foregroundStyle(.secondary)
                    TextField("0", text: $amountText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.leading)
                        .focused($focusedField, equals: .amount)
                        .fixedSize()
                        .onChange(of: amountText) { _, newValue in
                            let reformatted = Self.formatAmount(newValue)
                            if reformatted != amountText {
                                amountText = reformatted
                            }
                        }
                }
                .font(.system(.largeTitle, design: .monospaced).weight(.light))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
                .onTapGesture { focusedField = .amount }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.quickAmounts, id: \.self) { value in
                            Button {
                                amountText = (parsedAmount + value).formatted(.monopolyDigits)
                            } label: {
                                Text("+" + value.formatted(.monopolyMoney))
                            }
                            .buttonStyle(.glass)
                        }
                        Button(role: .destructive) {
                            amountText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .accessibilityLabel("Очистить сумму")
                        }
                        .buttonStyle(.glass)
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollClipDisabled()
            }
        }
        .padding(.vertical, 16)
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private func metaForm(viewModel: TransferViewModel) -> some View {
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

            Section("Назначение") {
                Picker("Тип", selection: $bindable.kind) {
                    ForEach(TransactionKind.allCases, id: \.self) { kind in
                        Label(kind.displayName, systemImage: kind.systemImageName)
                            .tag(kind)
                    }
                }
                TextField("Комментарий (необязательно)", text: $bindable.note, axis: .vertical)
                    .focused($focusedField, equals: .note)
                    .lineLimit(1...3)
            }

            Section {
                SubmitButton(
                    isEnabled: viewModel.canSubmit(amount: parsedAmount),
                    onSubmit: {
                        viewModel.submit(amount: parsedAmount)
                        if viewModel.didSucceed {
                            amountText = ""
                            focusedField = nil
                        }
                    }
                )
            }
        }
        .scrollDismissesKeyboard(.immediately)
        // Тап по любой неактивной области формы — скрываем клавиатуру.
        // simultaneousGesture срабатывает рядом с Form-овскими жестами,
        // .onTapGesture Form проглатывает.
        .simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        )
    }

    private func errorBinding(viewModel: TransferViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.lastError != nil },
            set: { if !$0 { viewModel.clearError() } }
        )
    }
}

private struct SubmitButton: View {
    let isEnabled: Bool
    let onSubmit: () -> Void

    var body: some View {
        Button(action: onSubmit) {
            Text("Перевести")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .disabled(!isEnabled)
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

// Money(parsing:) переехал в Domain/Money.swift — там его место, не здесь.
