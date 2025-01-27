//
//  ContentView.swift
//  MonopolyTracker
//
//  Created by vbncursed on 28/1/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var gameViewModel = GameViewModel()
    @State private var selectedPlayer: Player?
    @State private var isAddingPlayer: Bool = false
    @State private var showHistory: Bool = false
    @State private var amount: String = ""
    @State private var showResetAlert: Bool = false

    var body: some View {
        NavigationView {
            VStack {
                playerListView
            }
            .padding()
            .navigationTitle("Монополия")
            .navigationBarItems(
                leading: resetButton, // 🔹 Кнопка "Новая игра" слева
                trailing: HStack {
                    historyButton // 🔹 Кнопка "История"
                    addButton // 🔹 Кнопка "Добавить игрока"
                }
            )
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
            .sheet(item: $selectedPlayer) { player in
                TransactionModalView(
                    isPresented: Binding(
                        get: { selectedPlayer != nil },
                        set: { if !$0 { selectedPlayer = nil } }
                    ),
                    amount: $amount,
                    player: player
                ) { value in
                    gameViewModel.updateBalance(for: player, amount: value)
                }
            }
            .sheet(isPresented: $isAddingPlayer) {
                AddPlayerModalView(isPresented: $isAddingPlayer, gameViewModel: gameViewModel)
            }
            .sheet(isPresented: $showHistory) {
                TransactionHistoryView(gameViewModel: gameViewModel)
            }
            .alert(isPresented: $showResetAlert) {
                Alert(
                    title: Text("Новая игра"),
                    message: Text("Все игроки и балансы будут сброшены. Вы уверены?"),
                    primaryButton: .destructive(Text("Сбросить")) {
                        withAnimation {
                            gameViewModel.resetGame()
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    /// **Список игроков**
    private var playerListView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(gameViewModel.players) { player in
                    SwipeToDeleteView(content: {
                        playerCard(for: player)
                            .transition(.move(edge: .trailing))
                    }, onDelete: {
                        withAnimation {
                            gameViewModel.removePlayer(player)
                        }
                    })
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: gameViewModel.players)
    }

    /// **Карточка игрока**
    private func playerCard(for player: Player) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(player.name)
                    .font(.headline)
                    .bold()
                    .foregroundColor(.primary)
                Text("$\(player.balance)")
                    .font(.title3)
                    .bold()
                    .foregroundColor(.green)
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
        .onTapGesture {
            if selectedPlayer == nil {
                selectedPlayer = player
            }
        }
    }

    /// **Кнопка "Добавить" в правом верхнем углу**
    private var addButton: some View {
        Button(action: {
            isAddingPlayer = true
        }) {
            Image(systemName: "plus.circle.fill")
                .resizable()
                .frame(width: 28, height: 28)
                .foregroundColor(.blue)
        }
    }

    /// **Кнопка "История" в правом верхнем углу**
    private var historyButton: some View {
        Button(action: {
            showHistory = true
        }) {
            Image(systemName: "clock")
                .font(.title3)
                .foregroundColor(.blue)
        }
    }

    /// **Кнопка "Новая игра" в левом верхнем углу**
    private var resetButton: some View {
        Button(action: {
            showResetAlert = true
        }) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .resizable()
                .frame(width: 28, height: 28)
                .foregroundColor(.red)
        }
    }
}

#Preview {
    ContentView()
}
