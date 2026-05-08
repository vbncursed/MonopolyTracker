//
//  Item.swift
//  Monopoly Tracker
//
//  Created by vbncursed on 8/5/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
