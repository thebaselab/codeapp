//
//  PreviewProvider.swift
//  Code
//
//  Created by Ken Chung on 20/11/2022.
//

import Foundation

struct EditorProvider: Identifiable {
    let id = UUID()
    var registeredFileExtensions: [String]
    var onCreateEditor: (URL) -> EditorInstance
}

class EditorProviderManager: ObservableObject {

    @Published var providers: [EditorProvider] = []

    func register(provider: EditorProvider) {
        providers.append(provider)
    }

    func deregister(id: UUID) {
        providers.removeAll(where: { $0.id == id })
    }
}
