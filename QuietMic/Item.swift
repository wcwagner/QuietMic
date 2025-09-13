//
//  Item.swift
//  QuietMic
//
//  Created by William Wagner on 9/13/25.
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
