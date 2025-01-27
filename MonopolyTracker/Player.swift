//
//  Player.swift
//  MonopolyTracker
//
//  Created by vbncursed on 28/1/25.
//

import Foundation

struct Player: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var balance: Int

    init(id: UUID = UUID(), name: String, balance: Int) {
        self.id = id
        self.name = name
        self.balance = balance
    }
}
