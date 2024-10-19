//
//  AppExtensionService.swift
//  Code App
//
//  Created by Ken Chung on 02/07/2024.
//

import Dynamic
import Foundation
import ios_system

class AppExtensionService: NSObject {
    static let PORT = 50002
    static let shared = AppExtensionService()
    private var task: URLSessionWebSocketTask? = nil

    func startServer() {
        let BLE: AnyClass = (NSClassFromString("TlNFeHRlbnNpb24=".base64Decoded()!)!)
        let ext = Dynamic(BLE).extensionWithIdentifier(
            "thebaselab.VS-Code.extension", error: nil)
        let frameworkDir = Bundle.main.privateFrameworksPath!
        let frameworkDirBookmark = try! URL(fileURLWithPath: frameworkDir).bookmarkData()
        let pythonLibraryDirBookmark = try! FileManager().url(
            for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appendingPathComponent("lib/python3.9/site-packages").bookmarkData()
        let item = NSExtensionItem()
        item.userInfo = [
            "frameworksDirectoryBookmark": frameworkDirBookmark,
            "pythonLibraryDirectoryBookmark": pythonLibraryDirBookmark,
            "port": AppExtensionService.PORT,
        ]
        ext.setRequestInterruptionBlock(
            { uuid in
                print("Extension server crashed, attempting to restart")
                self.startServer()
            } as RequestInterruptionBlock)

        ext.beginExtensionRequestWithInputItems(
            [item],
            completion: { uuid in
                let pid = ext.pid(forRequestIdentifier: uuid)
                if let uuid = uuid {
                    print("Started extension request: \(uuid). Extension PID is \(pid)")
                }
                print("Extension server listening on 127.0.0.1:\(AppExtensionService.PORT)")
            } as RequestBeginBlock)

    }

    func stopServer() {
        let notificationName = CFNotificationName(
            "com.thebaselab.code.node.stop" as CFString)
        let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            notificationCenter, notificationName, nil, nil, false)
    }

    func terminate() {
        self.task?.cancel()
    }

    func prepareServer() async {
        if LanguageService.shared.candidateLanguageIdentifier == nil { return }
        stopServer()

        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
    }

    func call(
        args: [String],
        t_stdin: UnsafeMutablePointer<FILE>,
        t_stdout: UnsafeMutablePointer<FILE>
    ) async throws {
        await prepareServer()

        defer {
            self.task = nil
            signal(SIGINT, SIG_DFL)
        }

        let signalCallback: sig_t = { signal in
            // TODO: send real signal instead
            AppExtensionService.shared.terminate()
        }
        signal(SIGINT, signalCallback)

        let task = URLSession.shared.webSocketTask(
            with: URL(string: "ws://127.0.0.1:\(String(AppExtensionService.PORT))/websocket")!)
        self.task = task
        task.resume()

        let handle = FileHandle(fileDescriptor: fileno(t_stdin), closeOnDealloc: false)
        handle.readabilityHandler = { fileHandle in
            if let str = String(data: fileHandle.availableData, encoding: .utf8) {
                Task {
                    try await task.send(.string(str))
                    print("Sending -> \(str)")
                }
            }
        }

        let frame = ExecutionRequestFrame(
            args: args,
            redirectStderr: true,
            workingDirectoryBookmark: try? URL(
                fileURLWithPath: FileManager.default.currentDirectoryPath
            ).bookmarkData(),
            isLanguageService: false
        )

        try await task.send(.string(frame.stringRepresentation))

        print("Sending -> \(frame.stringRepresentation)")

        while let message = try? await task.receive() {
            switch message {
            case .string(let text):
                print("Receiving <- \(text)")
                fputs(text, t_stdout)
            default:
                continue
            }
        }
    }
}
