//
//  Transaction.swift
//  MonopolyTracker
//
//  Created by vbncursed on 28/1/25.
//

import Foundation

struct Transaction: Identifiable, Codable, Equatable {
    let id: UUID = UUID()
    let playerName: String
    let amount: Int
    let date: Date

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var formattedAmount: String {
        return amount > 0 ? "+$\(amount)" : "-$\(abs(amount))"
    }

    /// **Сравнение двух транзакций для Equatable**
    static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        return lhs.id == rhs.id
    }
}
