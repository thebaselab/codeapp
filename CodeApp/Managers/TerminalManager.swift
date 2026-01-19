//
//  TerminalManager.swift
//  Code
//
//  Created by Thales Matheus Mendonça Santos - January 2026
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Code", category: "TerminalManager")

/// Manages multiple terminal instances.
/// - Important: Access this class only from the main thread. Debug builds will assert this.
class TerminalManager: ObservableObject {
    @Published var terminals: [TerminalInstance] = []
    @Published var activeTerminalId: UUID?

    /// Tracks the terminal that initiated a remote connection for proper data routing
    @Published private(set) var remoteTerminalId: UUID?

    private var rootURL: URL
    private var options: TerminalOptions
    private var terminalServiceProvider: TerminalServiceProvider?
    private var terminalCounter: Int = 1

    /// Asserts that we're on the main thread in debug builds
    private func assertMainThread(_ function: String = #function) {
        assert(Thread.isMainThread, "TerminalManager.\(function) must be called on the main thread")
    }

    static let maxTerminals = 10

    /// Reads terminal options from UserDefaults.
    /// Useful during initialization when @AppStorage properties aren't yet accessible.
    static func readTerminalOptionsFromDefaults() -> TerminalOptions {
        if let rawValue = UserDefaults.standard.string(forKey: "terminalOptions"),
           let data = rawValue.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(TerminalOptions.self, from: data) {
            return decoded
        }
        return TerminalOptions()
    }

    var activeTerminal: TerminalInstance? {
        get {
            guard let id = activeTerminalId else { return terminals.first }
            return terminals.first { $0.id == id } ?? terminals.first
        }
        set {
            guard
                let id = newValue?.id,
                terminals.contains(where: { $0.id == id })
            else {
                let attemptedId = newValue?.id.uuidString ?? "nil"
                let availableIds = terminals.map { $0.id.uuidString }.joined(separator: ", ")
                logger.warning(
                    "active terminal set failed: attempted id: \(attemptedId, privacy: .public), available ids: [\(availableIds, privacy: .public)]"
                )
                setActiveTerminalId(nil)
                return
            }
            setActiveTerminalId(id)
        }
    }

    /// Returns the terminal designated for remote data.
    var remoteTerminal: TerminalInstance? {
        if let id = remoteTerminalId {
            return terminals.first { $0.id == id }
        }
        return terminals.first { $0.terminalServiceProvider != nil }
    }

    init(rootURL: URL, options: TerminalOptions) {
        self.rootURL = rootURL
        self.options = options
        self.terminalServiceProvider = nil

        // Create the initial terminal
        let initialName = String(
            format: NSLocalizedString("Terminal %d", comment: "Terminal name with number"),
            1
        )
        let initialTerminal = createTerminalInstance(name: initialName)
        terminals.append(initialTerminal)
        setActiveTerminalId(initialTerminal.id)
    }

    private func createTerminalInstance(name: String) -> TerminalInstance {
        let terminal = TerminalInstance(root: rootURL, options: options, name: name)
        if let provider = terminalServiceProvider, terminal.id == remoteTerminalId {
            terminal.terminalServiceProvider = provider
        }
        return terminal
    }

    /// Generates a unique terminal name by finding the lowest available number.
    /// This reuses gaps from closed terminals (e.g., if "Terminal 2" was closed, the next terminal uses "Terminal 2").
    private func generateUniqueTerminalName() -> String {
        let existingNames = Set(terminals.map { $0.name })

        // Find the lowest available terminal number
        var number = 1
        while number <= TerminalManager.maxTerminals + 1 {
            let candidateName = String(
                format: NSLocalizedString("Terminal %d", comment: "Terminal name with number"),
                number
            )
            if !existingNames.contains(candidateName) {
                return candidateName
            }
            number += 1
        }

        // Fallback: use counter with suffix (should rarely happen)
        terminalCounter += 1
        let baseName = String(
            format: NSLocalizedString("Terminal %d", comment: "Terminal name with number"),
            terminalCounter
        )
        let maxAttempts = TerminalManager.maxTerminals + 1
        var suffix = 1
        var candidateName = String(
            format: NSLocalizedString("%@ (%d)", comment: "Terminal name with duplicate suffix"),
            baseName, suffix
        )
        while existingNames.contains(candidateName) && suffix < maxAttempts {
            suffix += 1
            candidateName = String(
                format: NSLocalizedString("%@ (%d)", comment: "Terminal name with duplicate suffix"),
                baseName, suffix
            )
        }
        if existingNames.contains(candidateName) {
            terminalCounter += 1
            candidateName = String(
                format: NSLocalizedString(
                    "%@ (%d-%d)",
                    comment: "Terminal name with duplicate suffix and unique token"
                ),
                baseName,
                suffix,
                terminalCounter
            )
        }
        return candidateName
    }

    @discardableResult
    func createTerminal(name: String? = nil) -> TerminalInstance {
        assertMainThread()
        guard terminals.count < TerminalManager.maxTerminals else {
            logger.debug("create blocked: max reached (count: \(self.terminals.count, privacy: .public), max: \(TerminalManager.maxTerminals, privacy: .public))")
            // Return the active terminal if at max capacity
            // Invariant: terminals array is never empty after init (enforced by closeTerminal guard)
            precondition(!terminals.isEmpty, "TerminalManager must always have at least one terminal")
            return activeTerminal ?? terminals.first!
        }

        let terminalName = name ?? generateUniqueTerminalName()
        let terminal = createTerminalInstance(name: terminalName)
        terminals.append(terminal)
        setActiveTerminalId(terminal.id)
        logger.info("created terminal name: \(terminal.name, privacy: .public) id: \(terminal.id, privacy: .public)")
        return terminal
    }

    func closeTerminal(id: UUID) {
        assertMainThread()
        // Don't allow closing the last terminal
        guard terminals.count > 1 else {
            logger.debug("close blocked: last terminal (count: \(self.terminals.count, privacy: .public)) id: \(id, privacy: .public)")
            return
        }

        guard let index = terminals.firstIndex(where: { $0.id == id }) else {
            logger.debug("close failed: terminal not found id: \(id, privacy: .public)")
            return
        }

        // If closing active terminal, switch to another one
        if activeTerminalId == id {
            if index > 0 {
                setActiveTerminalId(terminals[index - 1].id)
            } else {
                setActiveTerminalId(terminals[1].id)
            }
        }
        // Clean up the terminal's resources using the cleanup method
        let terminal = terminals[index]
        terminal.cleanup()

        terminals.remove(at: index)
        syncRemoteTerminalId()
        logger.info("closed terminal name: \(terminal.name, privacy: .public) id: \(terminal.id, privacy: .public)")
    }

    /// Check if a terminal has a running process
    func isTerminalBusy(id: UUID) -> Bool {
        guard let terminal = terminals.first(where: { $0.id == id }) else { return false }
        return terminal.executor?.state == .running || terminal.executor?.state == .interactive
    }

    func setActiveTerminal(id: UUID) {
        assertMainThread()
        guard let terminal = terminals.first(where: { $0.id == id }) else {
            logger.debug("switch failed: terminal not found id: \(id, privacy: .public)")
            return
        }
        setActiveTerminalId(terminal.id)
        logger.info("switched terminal name: \(terminal.name, privacy: .public) id: \(terminal.id, privacy: .public)")
    }

    func renameTerminal(id: UUID, name: String) {
        assertMainThread()
        guard let terminal = terminals.first(where: { $0.id == id }) else { return }
        objectWillChange.send()
        terminal.name = name
    }

    func applyThemeToAll(rawTheme: [String: Any]) {
        assertMainThread()
        for terminal in terminals {
            terminal.applyTheme(rawTheme: rawTheme)
        }
    }

    func applyOptionsToAll(_ options: TerminalOptions) {
        assertMainThread()
        self.options = options
        for terminal in terminals {
            terminal.options = options
        }
    }

    func resetAndSetNewRootDirectory(url: URL) {
        assertMainThread()
        rootURL = url
        for terminal in terminals {
            terminal.resetAndSetNewRootDirectory(url: url)
        }
    }

    /// Sets the terminal service provider on the active terminal only.
    func setTerminalServiceProviderForAll(_ provider: TerminalServiceProvider?) {
        assertMainThread()
        terminalServiceProvider = provider
        let targetId = activeTerminalId ?? terminals.first?.id
        for terminal in terminals {
            terminal.terminalServiceProvider =
                terminal.id == targetId ? provider : nil
        }
        // Track the active terminal as the remote terminal when connecting
        if let provider = provider {
            provider.onDisconnect { [weak self] in
                DispatchQueue.main.async {
                    self?.setTerminalServiceProviderForAll(nil)
                }
            }
            remoteTerminalId = targetId
        } else {
            remoteTerminalId = nil
        }
        syncRemoteTerminalId()
    }

    var canCreateNewTerminal: Bool {
        terminals.count < TerminalManager.maxTerminals
    }

    private func setActiveTerminalId(_ id: UUID?) {
        activeTerminalId = id
        syncRemoteTerminalId()
    }

    private func syncRemoteTerminalId() {
        guard terminalServiceProvider != nil else {
            remoteTerminalId = nil
            return
        }

        if let active = activeTerminal, active.terminalServiceProvider != nil {
            remoteTerminalId = active.id
            return
        }

        if let currentId = remoteTerminalId,
           terminals.contains(where: { $0.id == currentId && $0.terminalServiceProvider != nil }) {
            return
        }

        remoteTerminalId = terminals.first { $0.terminalServiceProvider != nil }?.id
    }
}
