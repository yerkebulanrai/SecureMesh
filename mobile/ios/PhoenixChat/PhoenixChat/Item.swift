//
//  Item.swift
//  PhoenixChat
//
//  Created by Еркебулан Рай on 12/7/25.
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
