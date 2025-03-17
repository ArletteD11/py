//
//  Item.swift
//  PrioritizeYourself
//
//  Created by Arlette Duran on 11/26/23.
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
