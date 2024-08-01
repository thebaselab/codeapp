//
//  AppExtensionError.swift
//  Code
//
//  Created by Ken Chung on 02/07/2024.
//

import Foundation

struct ExecutionRequestFrame: Codable {
    var args: [String]
    var workingDirectoryBookmark: Data?

    var stringRepresentation: String {
        do {
            let data = try JSONEncoder().encode(self)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
}

enum AppExtensionError: String {
    case missingServerConfiguration = "Missing server configuration"
    case serverAlreadyStarted = "Server already started"
}

extension AppExtensionError: LocalizedError {
    var errorDescription: String? {
        self.rawValue
    }
}
