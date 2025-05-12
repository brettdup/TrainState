//
//  Item.swift
//  TrainState
//
//  Created by Brett du Plessis on 2025/05/12.
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
