//
//  CodeAssistantConfiguration.swift
//  CodeApp
//
//  Created by Arya Mirsepasi.
//

import Foundation

enum CodeAssistantProvider: String, CaseIterable, Identifiable {
    case openAI
    case anthropic
    case openRouter

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .anthropic:
            return "Anthropic"
        case .openRouter:
            return "OpenRouter"
        }
    }

    var iconName: String {
        switch self {
        case .openAI:
            return "openai"
        case .anthropic:
            return "anthropic"
        case .openRouter:
            return "o.circle"
        }
    }
    
    var isSystemIcon: Bool {
        switch self {
        case .openAI, .anthropic:
            return false
        case .openRouter:
            return true
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI:
            return "gpt-5"
        case .anthropic:
            return "claude-sonnet-4-5"
        case .openRouter:
            return "deepseek/deepseek-r1"
        }
    }

    var suggestedModels: [String] {
        switch self {
        case .openAI:
            return ["gpt-5", "gpt-5-mini", "gpt-4.1"]
        case .anthropic:
            return [
                "claude-sonnet-4-5",
                "claude-haiku-4-5",
                "claude-opus-4-1",
            ]
        case .openRouter:
            return [
                "deepseek/deepseek-r1",
                "deepseek/deepseek-chat",
                "google/gemini-2.0-flash-exp:free",
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
        case .openRouter:
            return "codeassistant.openrouter.apiKey"
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
