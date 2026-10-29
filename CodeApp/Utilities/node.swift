//
//  commandExecutor.swift
//  Code
//
//  Created by Ken Chung on 18/2/2021.
//

import Dynamic
import Foundation
import JavaScriptCore
import MobileCoreServices
import ios_system

typealias RequestCancellationBlock = @convention(block) (_ uuid: UUID?, _ error: Error?) -> Void
typealias RequestInterruptionBlock = @convention(block) (_ uuid: UUID?) -> Void
typealias RequestCompletionBlock =
    @convention(block) (_ uuid: UUID?, _ extensionItems: [Any]?) ->
    Void
typealias RequestBeginBlock = @convention(block) (_ uuid: UUID?) -> Void

private var thread_stdin_copy: UnsafeMutablePointer<FILE>? = nil
private var thread_stdout_copy: UnsafeMutablePointer<FILE>? = nil
private var thread_stderr_copy: UnsafeMutablePointer<FILE>? = nil

// Variables from `FOO=bar` script prefixes, so `node` started through ios_system (pipes, redirects) still gets them.
private var scriptEnvironment: [String: String] = [:]

func launchCommandInExtension(args: [String]?, environment: [String: String] = [:]) -> Int32 {
    guard let args else {
        return 1
    }

    thread_stdin_copy = thread_stdin
    thread_stdout_copy = thread_stdout

    setvbuf(thread_stdout_copy, nil, _IONBF, 0)
    setvbuf(thread_stdin_copy, nil, _IONBF, 0)

    let environment = scriptEnvironment.merging(environment) { _, new in new }
    var exitCode: Int32 = 0
    let sema = DispatchSemaphore(value: 0)
    Task {
        do {
            exitCode = try await AppExtensionService.shared.call(
                args: args, t_stdin: thread_stdin_copy!, t_stdout: thread_stdout_copy!,
                environment: environment)
        } catch {
            print("WSError", error)
            exitCode = 1
        }
        sema.signal()
    }
    sema.wait()

    refreshNodeCommands()

    return exitCode
}

@_cdecl("java")
public func java(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    return launchCommandInExtension(args: convertCArguments(argc: argc, argv: argv))
}

@_cdecl("javac")
public func javac(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    return launchCommandInExtension(args: convertCArguments(argc: argc, argv: argv))
}

@_cdecl("node")
public func node(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let args = convertCArguments(argc: argc, argv: argv)

    if args?.count == 1 {
        fputs("Welcome to Node.js v18.19.0. \nREPL is unavailable in Code App.\n", thread_stderr)
        return 1
    }

    return launchCommandInExtension(args: args)
}

@_cdecl("npm")
public func npm(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {

    guard let appGroupSharedLibrary = Resources.appGroupSharedLibrary else {
        fputs("App Group is unavailable. Did you properly configure it in Xcode?\n", thread_stderr)
        return -1
    }

    var args = convertCArguments(argc: argc, argv: argv)!

    if args == ["npm", "init"] {
        fputs("User input is unavailable, use npm init -y instead\n", thread_stderr)
        return 1
    }

    args.removeFirst()  // Remove `npm`

    if ["start", "test", "restart", "stop"].contains(args.first) {
        args = ["run"] + args
    }

    if args.first == "run" || args.first == "run-script" {
        return runPackageScript(
            name: args.count > 1 ? args[1] : nil,
            extraArguments: Array(args.dropFirst(2)),
            globalBinDirectory: appGroupSharedLibrary.appendingPathComponent("lib/bin"))
    }

    var packagejson = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    packagejson.appendPathComponent("package.json")

    if !FileManager.default.fileExists(atPath: packagejson.path) {
        try? "{}".write(to: packagejson, atomically: true, encoding: .utf8)
    }

    let npmURL = Resources.npm.appendingPathComponent("node_modules/.bin/npm")
    args = ["node", "--optimize-for-size", npmURL.path] + args

    return launchCommandInExtension(args: args)
}

@_cdecl("npx")
public func npx(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {

    var args = convertCArguments(argc: argc, argv: argv)!

    guard args.count > 1 else {
        return 1
    }

    args.removeFirst()  // Remove `npx`

    let cmd = args.first!

    guard
        let bin = findLocalBin(
            cmd, from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
    else {
        fputs(
            "npm ERR! command doesn't exist or is not supported: \(args.joined(separator: " "))\n",
            thread_stderr)
        return 1
    }

    prepareNodeBin(bin)

    args.removeFirst()

    return launchCommandInExtension(args: ["node", bin.path] + args)
}

@_cdecl("nodeg")
public func nodeg(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {

    guard let appGroupSharedLibrary = Resources.appGroupSharedLibrary else {
        fputs("App Group is unavailable. Did you properly configure it in Xcode?\n", thread_stderr)
        return -1
    }

    var args = convertCArguments(argc: argc, argv: argv)!

    let moduleURL = appGroupSharedLibrary.appendingPathComponent("lib/bin/\(args.removeFirst())")
        .resolvingSymlinksInPath()

    let prettierPath = moduleURL.path

    if var content = try? String(contentsOf: moduleURL) {
        if !content.contains("process.exit = () => {}") {
            content = content.replacingOccurrences(
                of: "#!/usr/bin/env node", with: "#!/usr/bin/env node\nprocess.exit = () => {}")
            try? content.write(to: moduleURL, atomically: true, encoding: .utf8)
        }
    }

    args = ["node", prettierPath] + args  // + ["--prefix", workingPath]

    return launchCommandInExtension(args: args)
}

// MARK: - package.json scripts

enum ScriptOperator {
    case and, or, sequence
}

struct ScriptWord {
    let value: String
    let raw: String
    /// Contains unquoted pipes, redirects, globs or variables that only a shell can expand.
    let needsShell: Bool
}

/// Node CLI shims run inside the extension process, so `process.exit` must not tear it down.
private func prepareNodeBin(_ url: URL) {
    guard var content = try? String(contentsOf: url, encoding: .utf8),
        !content.contains("process.exit = () => {}")
    else {
        return
    }
    content = content.replacingOccurrences(
        of: "#!/usr/bin/env node", with: "#!/usr/bin/env node\nprocess.exit = () => {}")
    try? content.write(to: url, atomically: true, encoding: .utf8)
}

private func resolvedExistingFile(_ url: URL) -> URL? {
    let resolved = url.resolvingSymlinksInPath()
    return FileManager.default.fileExists(atPath: resolved.path) ? resolved : nil
}

/// Walks up from `directory` like npm does, so scripts in workspaces find hoisted binaries.
private func findAncestor(of directory: URL, containing relativePath: String) -> URL? {
    var current = directory.standardizedFileURL
    while true {
        if let match = resolvedExistingFile(current.appendingPathComponent(relativePath)) {
            return match
        }
        let parent = current.deletingLastPathComponent()
        if parent.path == current.path {
            return nil
        }
        current = parent
    }
}

private func findLocalBin(_ name: String, from directory: URL) -> URL? {
    guard !name.contains("/") else { return nil }
    return findAncestor(of: directory, containing: "node_modules/.bin/\(name)")
}

/// Splits a script on unquoted `&&`, `||` and `;`, keeping the operator that precedes each command.
func splitScriptLine(_ line: String) -> [(ScriptOperator?, String)] {
    var commands: [(ScriptOperator?, String)] = []
    var current = ""
    var pendingOperator: ScriptOperator? = nil
    var quote: Character? = nil
    let characters = Array(line)
    var index = 0

    func flush(_ next: ScriptOperator?) {
        let command = current.trimmingCharacters(in: .whitespaces)
        if !command.isEmpty {
            commands.append((pendingOperator, command))
        }
        current = ""
        pendingOperator = next
    }

    while index < characters.count {
        let character = characters[index]
        let next: Character? = index + 1 < characters.count ? characters[index + 1] : nil

        if character == "\\", let next, quote != "'" {
            current.append(character)
            current.append(next)
            index += 2
            continue
        }

        if let activeQuote = quote {
            current.append(character)
            if character == activeQuote {
                quote = nil
            }
        } else if character == "'" || character == "\"" {
            quote = character
            current.append(character)
        } else if character == "&" && next == "&" {
            flush(.and)
            index += 1
        } else if character == "|" && next == "|" {
            flush(.or)
            index += 1
        } else if character == ";" {
            flush(.sequence)
        } else {
            current.append(character)
        }
        index += 1
    }
    flush(nil)
    return commands
}

/// Splits a command into words, honoring quotes and backslash escapes.
func tokenizeCommand(_ command: String) -> [ScriptWord] {
    var words: [ScriptWord] = []
    var value = ""
    var raw = ""
    var needsShell = false
    var inWord = false
    var quote: Character? = nil
    var iterator = command.makeIterator()

    func finishWord() {
        words.append(ScriptWord(value: value, raw: raw, needsShell: needsShell))
        value = ""
        raw = ""
        needsShell = false
        inWord = false
    }

    while let character = iterator.next() {
        if quote == nil && (character == " " || character == "\t") {
            if inWord {
                finishWord()
            }
            continue
        }
        inWord = true
        raw.append(character)

        if character == "\\" && quote != "'", let escaped = iterator.next() {
            raw.append(escaped)
            value.append(escaped)
        } else if let activeQuote = quote {
            if character == activeQuote {
                quote = nil
            } else {
                needsShell = needsShell || (activeQuote == "\"" && character == "$")
                value.append(character)
            }
        } else if character == "'" || character == "\"" {
            quote = character
        } else {
            needsShell = needsShell || "|<>$*?&".contains(character)
            value.append(character)
        }
    }
    if inWord {
        finishWord()
    }
    return words
}

func environmentAssignment(_ word: String) -> (name: String, value: String)? {
    guard let separator = word.firstIndex(of: "="), separator != word.startIndex else {
        return nil
    }
    let name = word[..<separator]
    let isValidName =
        name.allSatisfy { $0 == "_" || ($0.isASCII && ($0.isLetter || $0.isNumber)) }
        && !(name.first?.isNumber ?? true)
    guard isValidName else { return nil }
    return (String(name), String(word[word.index(after: separator)...]))
}

func shellQuoted(_ word: String) -> String {
    let safeCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./=:@%+,"))
    if !word.isEmpty && word.unicodeScalars.allSatisfy(safeCharacters.contains) {
        return word
    }
    return "'" + word.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

private func runScriptCommand(_ command: String, packageDirectory: URL, globalBinDirectory: URL)
    -> Int32
{
    var words = tokenizeCommand(command)
    var environment: [String: String] = [:]
    while let word = words.first {
        if word.value == "cross-env" {
            words.removeFirst()
            continue
        }
        guard let assignment = environmentAssignment(word.value) else { break }
        environment[assignment.name] = assignment.value
        words.removeFirst()
    }

    guard let executable = words.first?.value else { return 0 }
    let arguments = words.dropFirst()
    let bin =
        executable == "node"
        ? nil
        : findLocalBin(executable, from: packageDirectory)
            ?? resolvedExistingFile(globalBinDirectory.appendingPathComponent(executable))

    if !arguments.contains(where: \.needsShell) {
        if executable == "node" {
            return launchCommandInExtension(
                args: ["node"] + arguments.map(\.value), environment: environment)
        }
        if let bin {
            prepareNodeBin(bin)
            return launchCommandInExtension(
                args: ["node", bin.path] + arguments.map(\.value), environment: environment)
        }
    }

    // ios_system handles pipes, redirects, globs and $VAR expansion; node binaries run through its `node` command.
    var commandWords = words.map(\.raw)
    if let bin {
        prepareNodeBin(bin)
        commandWords[0] = "node " + shellQuoted(bin.path)
    }

    let previousScriptEnvironment = scriptEnvironment
    scriptEnvironment.merge(environment) { _, new in new }
    let previousValues = environment.keys.map { key in
        (key, getenv(key).map { String(cString: $0) })
    }
    for (key, value) in environment {
        setenv(key, value, 1)
    }
    defer {
        scriptEnvironment = previousScriptEnvironment
        for (key, value) in previousValues {
            if let value {
                setenv(key, value, 1)
            } else {
                unsetenv(key)
            }
        }
    }
    return runBuiltinCommand(commandWords.joined(separator: " "))
}

/// With `joinMainThread` disabled ios_system returns before the command finishes, so wait like Executor does.
private func runBuiltinCommand(_ command: String) -> Int32 {
    let pid = ios_fork()
    let launchStatus = ios_system(command)
    ios_waitpid(pid)
    ios_releaseThreadId(pid)
    return launchStatus != 0 ? launchStatus : ios_getCommandStatus()
}

private func runScriptLine(_ line: String, packageDirectory: URL, globalBinDirectory: URL) -> Int32
{
    var status: Int32 = 0
    for (scriptOperator, command) in splitScriptLine(line) {
        if (scriptOperator == .and && status != 0) || (scriptOperator == .or && status == 0) {
            continue
        }
        status = runScriptCommand(
            command, packageDirectory: packageDirectory, globalBinDirectory: globalBinDirectory)
    }
    return status
}

private func runPackageScript(name: String?, extraArguments: [String], globalBinDirectory: URL)
    -> Int32
{
    let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    guard let packageJSON = findAncestor(of: workingDirectory, containing: "package.json") else {
        fputs(
            "npm ERR! Could not find package.json in \(workingDirectory.path) or any parent directory\n",
            thread_stderr)
        return 1
    }
    let packageDirectory = packageJSON.deletingLastPathComponent()

    let scripts: [String: String]
    do {
        let data = try Data(contentsOf: packageJSON)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        scripts = json?["scripts"] as? [String: String] ?? [:]
    } catch {
        fputs(
            "npm ERR! Failed to parse \(packageJSON.path): \(error.localizedDescription)\n",
            thread_stderr)
        return 1
    }

    guard let name else {
        for (scriptName, script) in scripts.sorted(by: { $0.key < $1.key }) {
            fputs("  \(scriptName)\n    \(script)\n", thread_stdout)
        }
        return 0
    }

    guard let script = scripts[name] else {
        fputs("npm ERR! Missing script: \"\(name)\"\n", thread_stderr)
        return 1
    }

    let arguments =
        extraArguments.first == "--" ? Array(extraArguments.dropFirst()) : extraArguments
    let command = ([script] + arguments.map(shellQuoted)).joined(separator: " ")
    let steps = [scripts["pre\(name)"], command, scripts["post\(name)"]].compactMap { $0 }

    // ios_system tracks the directory per session, so plain chdir would not reach built-in commands.
    ios_setDirectoryURL(packageDirectory)
    defer { ios_setDirectoryURL(workingDirectory) }

    for step in steps {
        fputs("\n> \(step)\n\n", thread_stdout)
        let status = runScriptLine(
            step, packageDirectory: packageDirectory, globalBinDirectory: globalBinDirectory)
        if status != 0 {
            return status
        }
    }
    return 0
}
