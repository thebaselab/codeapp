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

var nodeUUID: UUID? = nil
var nodeStdoutWatcher: FolderMonitor?

typealias RequestCancellationBlock = @convention(block) (_ uuid: UUID?, _ error: Error?) -> Void
typealias RequestInterruptionBlock = @convention(block) (_ uuid: UUID?) -> Void
typealias RequestCompletionBlock = @convention(block) (_ uuid: UUID?, _ extensionItems: [Any]?) ->
    Void
typealias RequestBeginBlock = @convention(block) (_ uuid: UUID?) -> Void

func nodeCmd(args: [String]?) -> Int32 {
    var ended = false

    // We use a private API here to launch an extension programatically
    let BLE: AnyClass = (NSClassFromString("TlNFeHRlbnNpb24=".base64Decoded()!)!)
    let ext = Dynamic(BLE).extensionWithIdentifier("thebaselab.VS-Code.extension", error: nil)

    ext.setRequestCancellationBlock(
        { uuid, error in
            if let uuid = uuid, let error = error {
                print("Request \(uuid) cancelled. \(error)")
                ended = true
            }
        } as RequestCancellationBlock)

    ext.setRequestInterruptionBlock(
        { uuid in
            if let uuid = uuid {
                print("Request \(uuid) interrupted.")
                let nc = NotificationCenter.default
                nc.post(
                    name: Notification.Name("node.stdout"), object: nil,
                    userInfo: [
                        "content":
                            "Program interrupted. This could be caused by a memory limit or an error in your code.\n"
                    ])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    ended = true
                }
            }
        } as RequestInterruptionBlock)

    ext.setRequestCompletionBlock(
        { uuid, extensionItems in
            if let uuid = uuid {
                print(
                    "Request \(uuid) completed. Extension items: \(String(describing: extensionItems))"
                )
            }

            if let item = extensionItems?.first as? NSExtensionItem {
                if let data = item.userInfo?["result"] as? String {
                    let nc = NotificationCenter.default
                    nc.post(
                        name: Notification.Name("node.stdout"), object: nil,
                        userInfo: ["content": data])
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                ended = true
            }
        } as RequestCompletionBlock)

    let workingDir = FileManager.default.currentDirectoryPath
    guard let bookmark = try? URL(fileURLWithPath: workingDir).bookmarkData() else {
        return 0
    }

    let item = NSExtensionItem()

    item.userInfo = ["workingDirectoryBookmark": bookmark, "args": args!]

    ext.beginExtensionRequestWithInputItems(
        [item],
        completion: { uuid in
            let pid = ext.pid(forRequestIdentifier: uuid)
            if let uuid = uuid {
                nodeUUID = uuid
                print("Started extension request: \(uuid). Extension PID is \(pid)")
            }
        } as RequestBeginBlock)

    while ended != true {
        sleep(UInt32(1))
    }

    refreshNodeCommands()

    return 0
}

@_cdecl("node")
public func node(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let args = convertCArguments(argc: argc, argv: argv)

    if args?.count == 1 {
        fputs("Welcome to Node.js v16.17.0. \nREPL is unavailable in Code App.\n", thread_stderr)
        return 1
    }

    return nodeCmd(args: args)
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
                        return nodeCmd(args: script.components(separatedBy: " "))
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
                                return nodeCmd(args: ["node", prettierPath, script])
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

                    return nodeCmd(args: ["node", bin.path] + cmdArgs)
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
    args = ["node", "--max-old-space-size=180", "--optimize-for-size", npmURL.path] + args

    return nodeCmd(args: args)
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

    return nodeCmd(args: ["node", bin.path] + args)
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

    return nodeCmd(args: args)
}
