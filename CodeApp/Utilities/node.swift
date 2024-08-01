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
typealias RequestCompletionBlock = @convention(block) (_ uuid: UUID?, _ extensionItems: [Any]?) ->
    Void
typealias RequestBeginBlock = @convention(block) (_ uuid: UUID?) -> Void

private var thread_stdin_copy: UnsafeMutablePointer<FILE>? = nil
private var thread_stdout_copy: UnsafeMutablePointer<FILE>? = nil
private var thread_stderr_copy: UnsafeMutablePointer<FILE>? = nil

func launchCommandInExtension(args: [String]?) -> Int32 {
    guard let args else {
        return 1
    }

    thread_stdin_copy = thread_stdin
    thread_stdout_copy = thread_stdout

    setvbuf(thread_stdout_copy, nil, _IONBF, 0)
    setvbuf(thread_stdin_copy, nil, _IONBF, 0)

    let sema = DispatchSemaphore(value: 0)
    Task {
        do {
            try await AppExtensionService.shared.call(
                args: args, t_stdin: thread_stdin_copy!, t_stdout: thread_stdout_copy!)
        } catch {
            print("WSError", error)
        }
        sema.signal()
    }
    sema.wait()

    refreshNodeCommands()

    return 0
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

    var packagejson = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    packagejson.appendPathComponent("package.json")

    if !FileManager.default.fileExists(atPath: packagejson.path) {
        try? "{}".write(to: packagejson, atomically: true, encoding: .utf8)
    }

    if ["start", "test", "restart", "stop"].contains(args.first) {
        args = ["run"] + args
    }

    if args.first == "run" {

        guard args.count > 1 else {
            return 1
        }

        var workingPath = FileManager.default.currentDirectoryPath
        if !workingPath.hasSuffix("/") {
            workingPath.append("/")
        }
        workingPath.append("package.json")

        do {
            let data = try Data(
                contentsOf: URL(fileURLWithPath: workingPath), options: .mappedIfSafe)
            let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
            if let jsonResult = jsonResult as? [String: AnyObject],
                let scripts = jsonResult["scripts"] as? [String: String]
            {
                if var script = scripts[args[1]] {

                    guard let cmd = script.components(separatedBy: " ").first else {
                        return 1
                    }
                    if cmd == "node" {
                        return launchCommandInExtension(args: script.components(separatedBy: " "))
                    }

                    script.removeFirst(cmd.count)

                    if script.hasPrefix(" ") {
                        script.removeFirst()
                    }

                    let cmdArgs = script.components(separatedBy: " ")

                    // Checking for globally installed bin
                    let nodeBinPath = appGroupSharedLibrary.appendingPathComponent("lib/bin").path

                    if let paths = try? FileManager.default.contentsOfDirectory(atPath: nodeBinPath)
                    {
                        print(nodeBinPath)
                        for i in paths {
                            let binCmd = i.replacingOccurrences(of: nodeBinPath, with: "")
                            if cmd == binCmd {
                                let moduleURL = appGroupSharedLibrary.appendingPathComponent(
                                    "lib/bin/\(cmd)"
                                )
                                .resolvingSymlinksInPath()

                                let prettierPath = moduleURL.path

                                if var content = try? String(contentsOf: moduleURL) {
                                    if !content.contains("process.exit = () => {}") {
                                        content = content.replacingOccurrences(
                                            of: "#!/usr/bin/env node",
                                            with: "#!/usr/bin/env node\nprocess.exit = () => {}")
                                        try? content.write(
                                            to: moduleURL, atomically: true, encoding: .utf8)
                                    }
                                }

                                print(["node", prettierPath, script])
                                return launchCommandInExtension(args: [
                                    "node", prettierPath, script,
                                ])
                            }
                        }
                    }

                    // Checking for locally installed bin
                    var bin = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    bin.appendPathComponent("node_modules/.bin/\(cmd)")
                    bin.resolveSymlinksInPath()

                    guard FileManager.default.fileExists(atPath: bin.path) else {
                        fputs(
                            "npm ERR! command doesn't exist or is not supported: \(scripts[args[1]]!)\n",
                            thread_stderr)
                        return 1
                    }

                    if var content = try? String(contentsOf: bin) {
                        if !content.contains("process.exit = () => {}") {
                            content = content.replacingOccurrences(
                                of: "#!/usr/bin/env node",
                                with: "#!/usr/bin/env node\nprocess.exit = () => {}")
                            try? content.write(to: bin, atomically: true, encoding: .utf8)
                        }
                    }

                    return launchCommandInExtension(args: ["node", bin.path] + cmdArgs)
                } else {
                    fputs("npm ERR! missing script: \(args[1])\n", thread_stderr)
                }
            }
        } catch {
            fputs(error.localizedDescription, thread_stderr)
        }

        return 1
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

    var bin = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    bin.appendPathComponent("node_modules/.bin/\(cmd)")

    guard FileManager.default.fileExists(atPath: bin.path) else {
        fputs(
            "npm ERR! command doesn't exist or is not supported: \(args.joined(separator: " "))\n",
            thread_stderr)
        return 1
    }

    bin.resolveSymlinksInPath()

    if var content = try? String(contentsOf: bin) {
        if !content.contains("process.exit = () => {}") {
            content = content.replacingOccurrences(
                of: "#!/usr/bin/env node", with: "#!/usr/bin/env node\nprocess.exit = () => {}")
            try? content.write(to: bin, atomically: true, encoding: .utf8)
        }
    }

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
