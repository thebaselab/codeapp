//
//  CodeAppContributionPointManager.swift
//  Code
//
//  Created by Ken Chung on 15/8/2023.
//

import SwiftUI

protocol CodeAppContributionPointManager: ObservableObject {
    associatedtype Item where Item: Identifiable, Item.ID == UUID
    var items: [Item] { get set }
    func registerItem(item: Item)
    func deregisterItem(id: UUID)
}

extension CodeAppContributionPointManager {
    func registerItem(item: Item) {
        items.append(item)
    }
    func deregisterItem(id: UUID) {
        items.removeAll(where: { $0.id == id })
    }
}
