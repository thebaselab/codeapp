//
//  ToolbarManager.swift
//  Code
//
//  Created by Ken Chung on 14/11/2022.
//

import Foundation

class ToolbarManager: ObservableObject {
    @Published var items: [ToolbarItem] = []

    func registerItem(item: ToolbarItem) {
        items.append(item)
    }

    func deregister(id: UUID) {
        items.removeAll(where: { $0.id == id })
    }
}
