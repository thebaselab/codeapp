//
//  CodeAssistantViewModel.swift
//  CodeApp
//
//  Created by Arya Mirsepasi.
//

import AIProxy
import Foundation

@MainActor
final class CodeAssistantViewModel: ObservableObject {

    struct Message: Identifiable, Codable {
        enum Role: String, Codable {
            case user
            case assistant
            case system
        }

        let id: UUID
        var role: Role
        var body: String
        var payload: String
        let createdAt: Date
        var attachments: [Attachment]
        var isStreaming: Bool
        var errorDescription: String?

        init(
            id: UUID = UUID(),
            role: Role,
            body: String,
            payload: String,
            createdAt: Date = Date(),
            attachments: [Attachment] = [],
            isStreaming: Bool = false,
            errorDescription: String? = nil
        ) {
            self.id = id
            self.role = role
            self.body = body
            self.payload = payload
            self.createdAt = createdAt
            self.attachments = attachments
            self.isStreaming = isStreaming
            self.errorDescription = errorDescription
        }
    }

    struct Attachment: Identifiable, Equatable, Codable {
        let id: UUID
        let url: URL
        let name: String
        let byteCount: Int
        let content: String
        let languageHint: String
        let wasTruncated: Bool

        init(
            id: UUID = UUID(),
            url: URL,
            name: String,
            byteCount: Int,
            content: String,
            languageHint: String,
            wasTruncated: Bool
        ) {
            self.id = id
            self.url = url
            self.name = name
            self.byteCount = byteCount
            self.content = content
            self.languageHint = languageHint
            self.wasTruncated = wasTruncated
        }

        var formattedSize: String {
            byteCount > 1024 ? "\(byteCount / 1024) KB" : "\(byteCount) B"
        }

        var promptBlock: String {
            """
            Attached file: \(name)
            ```\(languageHint)
            \(content)
            ```
            \(wasTruncated ? "_(truncated attachment)_": "")
            """
        }
    }

    enum AssistantError: LocalizedError {
        case missingAPIKey(provider: CodeAssistantProvider)
        case unsupportedAttachment
        case failedToReadFile
        case upstreamError(String)

        var errorDescription: String? {
            switch self {
            case let .missingAPIKey(provider):
                return "\(provider.displayName) API key is missing. Set it in Settings."
            case .unsupportedAttachment:
                return "Only UTF-8 text based files can be attached."
            case .failedToReadFile:
                return "Unable to read the selected file."
            case let .upstreamError(message):
                return message
            }
        }
    }

    struct Conversation: Identifiable, Codable {
        let id: UUID
        var title: String
        var messages: [Message]
        var createdAt: Date
    }

    @Published var isPresented: Bool = false
    @Published var messages: [Message] = []
    @Published var currentInput: String = ""
    @Published var attachments: [Attachment] = []
    @Published var selectedProvider: CodeAssistantProvider {
        didSet {
            defaults.set(selectedProvider.rawValue, forKey: Self.providerDefaultsKey)
        }
    }
    @Published var isStreaming: Bool = false
    @Published var errorMessage: String?
    @Published var history: [Conversation] = [] {
        didSet {
            persistHistory()
        }
    }
    @Published var activeConversationTitle: String = "New Chat"

    var currentModel: String {
        modelOverrides[selectedProvider] ?? selectedProvider.defaultModel
    }

    var canSend: Bool {
        !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !attachments.isEmpty
    }

    private let defaults: UserDefaults
    private var modelOverrides: [CodeAssistantProvider: String] = [:]
    private var streamTask: Task<Void, Never>?
    private let systemPrompt =
        """
        You are Code App's AI coding assistant. Provide concise, actionable answers using clear Markdown formatting. Follow best practices, robust patterns, and modern UI/UX principles. When offering code, prefer idiomatic, production-ready solutions with comments where helpful, and include brief explanations and alternatives when relevant.
        
        You specialize in the following runtimes and should tailor examples and guidance accordingly:
        - Python 3.9.2
        - Clang 14.0.0 (C/C++)
        - PHP 8.3.2
        - Node.js 18.19.0
        - OpenJDK 8 (Java)
        
        Guidelines:
        - Be precise and avoid unnecessary verbosity.
        - Validate assumptions and ask for missing details when needed.
        - Emphasize security, performance, readability, and maintainability.
        - Provide step-by-step migration or debugging advice when appropriate.
        - Use platform-appropriate tooling, testing, and packaging recommendations.
        - When presenting code blocks, specify the correct language for syntax highlighting.
        """

    private static let providerDefaultsKey = "codeassistant.provider.active"
    private static func modelDefaultsKey(for provider: CodeAssistantProvider) -> String {
        "codeassistant.model.\(provider.rawValue)"
    }

    private static let maxAttachmentCharacters = 24_000
    private var activeConversationID = UUID()
    private static let historyDefaultsKey = "codeassistant.history.archive"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if
            let storedProvider = defaults.string(forKey: Self.providerDefaultsKey),
            let provider = CodeAssistantProvider(rawValue: storedProvider)
        {
            selectedProvider = provider
        } else {
            selectedProvider = .openAI
        }

        for provider in CodeAssistantProvider.allCases {
            let storedModel = defaults.string(forKey: Self.modelDefaultsKey(for: provider))
            modelOverrides[provider] = storedModel ?? provider.defaultModel
        }
        loadHistory()
    }

    func updateModel(_ value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalValue = normalized.isEmpty ? selectedProvider.defaultModel : normalized
        modelOverrides[selectedProvider] = finalValue
        defaults.set(finalValue, forKey: Self.modelDefaultsKey(for: selectedProvider))
    }

    func attach(item: WorkSpaceStorage.FileItemRepresentable) {
        guard let url = item._url else {
            errorMessage = AssistantError.failedToReadFile.errorDescription
            return
        }
        Task.detached(priority: .userInitiated) {
            let attachment = await Self.buildAttachment(from: url, displayName: item.name)
            await MainActor.run {
                switch attachment {
                case let .success(result):
                    if !self.attachments.contains(where: { $0.url == result.url }) {
                        self.attachments.append(result)
                    }
                    self.errorMessage = nil
                case let .failure(error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func removeAttachment(_ attachment: Attachment) {
        attachments.removeAll { $0.id == attachment.id }
    }

    func clearConversation() {
        startNewConversation()
    }

    func startNewConversation() {
        archiveCurrentConversationIfNeeded()
        stopStreaming()
        messages.removeAll()
        attachments.removeAll()
        currentInput = ""
        errorMessage = nil
        activeConversationID = UUID()
        activeConversationTitle = "New Chat"
    }

    func loadConversation(_ conversation: Conversation) {
        archiveCurrentConversationIfNeeded()
        stopStreaming()
        history.removeAll { $0.id == conversation.id }
        messages = conversation.messages
        activeConversationID = conversation.id
        activeConversationTitle = conversation.title
        currentInput = ""
        attachments.removeAll()
        errorMessage = nil
    }

    func deleteConversation(_ conversation: Conversation) {
        history.removeAll { $0.id == conversation.id }
    }

    func clearHistory() {
        history.removeAll()
    }

    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        if let index = messages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) {
            messages[index].isStreaming = false
        }
    }

    func sendMessage() {
        let trimmed = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !attachments.isEmpty else {
            return
        }
        let userPayload = buildPayload(for: trimmed, attachments: attachments)

        let userMessage = Message(
            role: .user,
            body: trimmed.isEmpty ? "Attached files" : trimmed,
            payload: userPayload,
            attachments: attachments
        )
        messages.append(userMessage)
        if messages.count == 1 {
            activeConversationTitle = deriveTitle(from: messages)
        }
        currentInput = ""

        let placeholder = Message(
            role: .assistant,
            body: "",
            payload: "",
            attachments: [],
            isStreaming: true
        )
        messages.append(placeholder)
        isStreaming = true
        errorMessage = nil

        let conversationContext = messages.filter { $0.id != placeholder.id }
        let provider = selectedProvider
        let model = currentModel

        attachments.removeAll()

        streamTask = Task {
            do {
                switch provider {
                case .openAI:
                    try await streamOpenAI(
                        history: conversationContext,
                        placeholderID: placeholder.id,
                        model: model)
                case .anthropic:
                    try await requestAnthropic(
                        history: conversationContext,
                        placeholderID: placeholder.id,
                        model: model)
                }
            } catch {
                await MainActor.run {
                    self.handle(error: error, placeholderID: placeholder.id)
                }
            }
        }
    }

    private func handle(error: Error, placeholderID: UUID) {
        if let index = messages.firstIndex(where: { $0.id == placeholderID }) {
            messages[index].isStreaming = false
            messages[index].errorDescription = error.localizedDescription
        }
        errorMessage = error.localizedDescription
        isStreaming = false
        streamTask = nil
    }

    private func finalizeStream(for placeholderID: UUID) {
        if let index = messages.firstIndex(where: { $0.id == placeholderID }) {
            messages[index].isStreaming = false
            messages[index].payload = messages[index].body
        }
        isStreaming = false
        streamTask = nil
    }

    private func streamOpenAI(
        history: [Message],
        placeholderID: UUID,
        model: String
    ) async throws {
        let apiKey = CodeAssistantSettings.apiKey(for: .openAI)
        guard !apiKey.isEmpty else {
            throw AssistantError.missingAPIKey(provider: .openAI)
        }

        let service = AIProxy.openAIDirectService(unprotectedAPIKey: apiKey)
        let requestBody = OpenAIChatCompletionRequestBody(
            model: model,
            messages: openAIMessages(from: history),
            temperature: 0.2
        )

        let stream = try await service.streamingChatCompletionRequest(body: requestBody, secondsToWait: 60)
        do {
            for try await chunk in stream {
                guard let delta = chunk.choices.first?.delta.content else {
                    continue
                }
                if let index = messages.firstIndex(where: { $0.id == placeholderID }) {
                    messages[index].body += delta
                }
            }
            finalizeStream(for: placeholderID)
        } catch {
            throw error
        }
    }

    private func requestAnthropic(
        history: [Message],
        placeholderID: UUID,
        model: String
    ) async throws {
        let apiKey = CodeAssistantSettings.apiKey(for: .anthropic)
        guard !apiKey.isEmpty else {
            throw AssistantError.missingAPIKey(provider: .anthropic)
        }

        let service = AIProxy.anthropicDirectService(unprotectedAPIKey: apiKey)
        let body = AnthropicMessageRequestBody(
            maxTokens: 1024,
            messages: anthropicMessages(from: history),
            model: model
        )

        do {
            let response = try await service.messageRequest(body: body)
            var aggregate = ""
            for content in response.content {
                if case let .text(text) = content {
                    aggregate += text
                }
            }
            if let index = messages.firstIndex(where: { $0.id == placeholderID }) {
                messages[index].body = aggregate
            }
            finalizeStream(for: placeholderID)
        } catch {
            throw error
        }
    }

    private func openAIMessages(from history: [Message]) -> [OpenAIChatCompletionRequestBody.Message] {
        var payload: [OpenAIChatCompletionRequestBody.Message] = [
            .system(content: .text(systemPrompt))
        ]
        payload += history.compactMap { message in
            switch message.role {
            case .user:
                return .user(content: .text(message.payload))
            case .assistant:
                return .assistant(content: .text(message.payload))
            case .system:
                return .system(content: .text(message.payload))
            }
        }
        return payload
    }

    private func anthropicMessages(from history: [Message]) -> [AnthropicInputMessage] {
        var payload = [
            AnthropicInputMessage(content: [.text(systemPrompt)], role: .user)
        ]
        payload += history.compactMap { message in
            switch message.role {
            case .user:
                return AnthropicInputMessage(content: [.text(message.payload)], role: .user)
            case .assistant:
                return AnthropicInputMessage(content: [.text(message.payload)], role: .assistant)
            case .system:
                return nil
            }
        }
        return payload
    }

    private func buildPayload(for text: String, attachments: [Attachment]) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachmentBlock = attachments.map(\.promptBlock).joined(separator: "\n\n")
        return [trimmed, attachmentBlock]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private static func buildAttachment(from url: URL, displayName: String) -> Result<
        Attachment, AssistantError
    > {
        do {
            let data = try Data(contentsOf: url)
            guard let content = String(data: data, encoding: .utf8) else {
                return .failure(.unsupportedAttachment)
            }
            var text = content
            var truncated = false
            if text.count > maxAttachmentCharacters {
                let index = text.index(text.startIndex, offsetBy: maxAttachmentCharacters)
                text = String(text[..<index])
                truncated = true
            }
            return .success(
                Attachment(
                    url: url,
                    name: displayName,
                    byteCount: data.count,
                    content: text,
                    languageHint: languageHint(for: url),
                    wasTruncated: truncated
                )
            )
        } catch {
            return .failure(.failedToReadFile)
        }
    }

    private static func languageHint(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        let mapping: [String: String] = [
            "swift": "swift",
            "m": "objectivec",
            "mm": "objectivec",
            "h": "c",
            "hpp": "cpp",
            "cpp": "cpp",
            "c": "c",
            "cc": "cpp",
            "js": "javascript",
            "ts": "typescript",
            "tsx": "tsx",
            "jsx": "jsx",
            "kt": "kotlin",
            "java": "java",
            "py": "python",
            "rb": "ruby",
            "php": "php",
            "cs": "csharp",
            "rs": "rust",
            "go": "go",
            "sql": "sql",
            "json": "json",
            "yml": "yaml",
            "yaml": "yaml",
            "sh": "bash",
            "bat": "batch",
            "md": "markdown",
            "html": "html",
            "css": "css",
            "scss": "scss",
        ]
        return mapping[ext] ?? "text"
    }

    private func persistHistory() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(history) else { return }
        defaults.set(data, forKey: Self.historyDefaultsKey)
    }

    private func loadHistory() {
        guard let data = defaults.data(forKey: Self.historyDefaultsKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let stored = try? decoder.decode([Conversation].self, from: data) else { return }
        history = stored
    }

    private func archiveCurrentConversationIfNeeded() {
        guard !messages.isEmpty else { return }
        let snapshot = Conversation(
            id: activeConversationID,
            title: deriveTitle(from: messages),
            messages: messages,
            createdAt: Date()
        )
        history.removeAll { $0.id == snapshot.id }
        history.insert(snapshot, at: 0)
        if history.count > 20 {
            history = Array(history.prefix(20))
        }
    }

    private func deriveTitle(from messages: [Message]) -> String {
        if let firstUser = messages.first(where: { $0.role == .user }) {
            let trimmed = firstUser.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed.count > 40 ? String(trimmed.prefix(40)) + "…" : trimmed
            }
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "Chat \(formatter.string(from: Date()))"
    }
}
