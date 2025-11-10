//
//  CodeAssistantConfiguration.swift
//  CodeApp
//
//  Created by Codex.
//

import Foundation

enum CodeAssistantProvider: String, CaseIterable, Identifiable {
    case openAI
    case anthropic

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .anthropic:
            return "Anthropic"
        }
    }

    var iconSystemName: String {
        switch self {
        case .openAI:
            return "sparkles"
        case .anthropic:
            return "circle.hexagongrid"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI:
            return "gpt-4o-mini"
        case .anthropic:
            return "claude-3-5-sonnet-20240620"
        }
    }

    var suggestedModels: [String] {
        switch self {
        case .openAI:
            return ["gpt-4o-mini", "gpt-4o", "gpt-4.1"]
        case .anthropic:
            return [
                "claude-3-5-sonnet-20240620",
                "claude-3-5-haiku-20241022",
                "claude-3-opus-20240229",
            ]
        }
    }
}

enum CodeAssistantSettings {
    private static func keychainKey(for provider: CodeAssistantProvider) -> String {
        switch provider {
        case .openAI:
            return "codeassistant.openai.apiKey"
        case .anthropic:
            return "codeassistant.anthropic.apiKey"
        }
    }

    static func apiKey(for provider: CodeAssistantProvider) -> String {
        KeychainAccessor.shared.getObjectString(for: keychainKey(for: provider)) ?? ""
    }

    static func persist(apiKey: String, for provider: CodeAssistantProvider) {
        let key = keychainKey(for: provider)
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _ = KeychainAccessor.shared.removeObjectForKey(for: key)
        } else {
            KeychainAccessor.shared.storeObject(for: key, value: apiKey)
        }
    }
}
