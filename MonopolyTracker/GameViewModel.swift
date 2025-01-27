//
//  GameViewModel.swift
//  MonopolyTracker
//
//  Created by vbncursed on 28/1/25.
//

import Foundation

class GameViewModel: ObservableObject {
    @Published var players: [Player] = [] {
        didSet { saveGame() }
    }

    @Published var transactions: [Transaction] = [] {
        didSet { saveTransactions() } // 🔹 Автосохранение истории
    }

    private let saveKey = "SavedPlayers"
    private let transactionsKey = "SavedTransactions"

    init() {
        loadGame()
        loadTransactions()
    }

    func addPlayer(name: String) {
        let newPlayer = Player(name: name, balance: 1500)
        players.append(newPlayer)
    }

    func updateBalance(for player: Player, amount: Int) {
        if let index = players.firstIndex(where: { $0.id == player.id }) {
            players[index].balance += amount
            let transaction = Transaction(playerName: player.name, amount: amount, date: Date())
            transactions.insert(transaction, at: 0) // 🔹 Новые транзакции сверху
        }
    }

    func removePlayer(_ player: Player) {
        players.removeAll { $0.id == player.id }
    }

    /// **Сброс игры (игроки + история)**
    func resetGame() {
        players = []
        transactions = []
        UserDefaults.standard.removeObject(forKey: saveKey)
        UserDefaults.standard.removeObject(forKey: transactionsKey)
    }

    /// **Сохранение игроков**
    private func saveGame() {
        if let encoded = try? JSONEncoder().encode(players) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    /// **Сохранение истории транзакций**
    private func saveTransactions() {
        if let encoded = try? JSONEncoder().encode(transactions) {
            UserDefaults.standard.set(encoded, forKey: transactionsKey)
        }
    }

    /// **Загрузка игроков**
    private func loadGame() {
        if let savedData = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Player].self, from: savedData) {
            players = decoded
        }
    }

    /// **Загрузка истории транзакций**
    private func loadTransactions() {
        if let savedData = UserDefaults.standard.data(forKey: transactionsKey),
           let decoded = try? JSONDecoder().decode([Transaction].self, from: savedData) {
            transactions = decoded
        }
    }
}
