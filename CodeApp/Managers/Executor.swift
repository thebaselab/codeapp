//
//  executor.swift
//  Code App
//
//  Created by Ken Chung on 12/12/2020.
//

import SwiftUI
import ios_system

class Executor {

    enum State {
        case idle
        case running
        case interactive
    }

    private let persistentIdentifier = "com.thebaselab.terminal"
    private var pid: pid_t? = nil

    private var stdin_file: UnsafeMutablePointer<FILE>?
    private var stdout_file: UnsafeMutablePointer<FILE>?
    private var stdin_file_input: FileHandle? = nil

    private var receivedStdout: ((_ data: Data) -> Void)
    private var receivedStderr: ((_ data: Data) -> Void)
    private var requestInput: ((_ prompt: String) -> Void)
    private var lastCommand: String? = nil
    private var stdout_active = false
    private let END_OF_TRANSMISSION = "\u{04}"

    var currentWorkingDirectory: URL
    var state: State = .idle
    var prompt: String

    func setNewWorkingDirectory(url: URL) {
        currentWorkingDirectory = url
        prompt = "\(url.lastPathComponent) $ "
    }

    init(
        root: URL, onStdout: @escaping ((_ data: Data) -> Void),
        onStderr: @escaping ((_ data: Data) -> Void),
        onRequestInput: @escaping ((_ prompt: String) -> Void)
    ) {
        currentWorkingDirectory = root
        prompt = "\(root.lastPathComponent) $ "
        receivedStdout = onStdout
        receivedStderr = onStderr
        requestInput = onRequestInput
    }

    func evaluateCommands(_ cmds: [String]) {
        guard !cmds.isEmpty else {
            return
        }
        var commands = cmds
        dispatch(
            command: commands.removeFirst(),
            completionHandler: { code in
                if !commands.isEmpty && code == 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.evaluateCommands(commands)
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.prompt =
                            "\(FileManager().currentDirectoryPath.split(separator: "/").last?.removingPercentEncoding ?? "") $ "
                        self.requestInput(self.prompt)
                    }
                }
            })
    }

    func endOfTransmission() {
        try? stdin_file_input?.close()
    }

    func kill() {
        if nodeUUID != nil {
            let notificationName = CFNotificationName(
                "com.thebaselab.code.node.stop" as CFString)
            let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
            CFNotificationCenterPostNotification(
                notificationCenter, notificationName, nil, nil, false)
        }

        ios_switchSession(persistentIdentifier.toCString())
        ios_kill()
    }

    func setWindowSize(cols: Int, rows: Int) {
        ios_setWindowSize(Int32(cols), Int32(rows), persistentIdentifier.toCString())
    }

    func sendInput(input: String) {
        guard self.state != .idle, let data = input.data(using: .utf8) else {
            return
        }

        // For wasm
        if state == .running {
            stdinString += input + "\n"
        }

        ios_switchSession(persistentIdentifier.toCString())

        stdin_file_input?.write(data)

        if state == .running {
            if let endData = "\n".data(using: .utf8) {
                stdin_file_input?.write(endData)
            }
        }

    }

    private func onStdout(_ stdout: FileHandle) {
        if !stdout_active { return }

        let data = stdout.availableData
        let str = String(decoding: data, as: UTF8.self)

        if str.contains(END_OF_TRANSMISSION) {
            stdout_active = false
            return
        }

        DispatchQueue.main.async {

            if self.state == .running {
                // Interactive Commands /with control characters
                if str.contains("\u{8}") || str.contains("\u{13}") || str.contains("\r") {
                    self.receivedStdout(data)
                    return
                }
                self.requestInput(str)
                if let prom = str.components(separatedBy: "\n").last {
                    self.prompt = prom
                }
            } else {
                self.receivedStdout(data)
            }
        }
    }

    // Called when the stderr file handle is written to
    private func onStderr(_ stderr: FileHandle) {
        let data = stderr.availableData
        DispatchQueue.main.async {
            if self.state == .running {
                let str = String(decoding: data, as: UTF8.self)
                self.requestInput(str)
                if let prom = str.components(separatedBy: "\n").last {
                    self.prompt = prom
                }
            } else {
                self.receivedStdout(data)
            }
        }
    }

    func dispatch(
        command: String, isInteractive: Bool = false, completionHandler: @escaping (Int32) -> Void
    ) {
        guard command != "" else {
            completionHandler(0)
            return
        }

        var stdin_pipe = Pipe()
        stdin_file = fdopen(stdin_pipe.fileHandleForReading.fileDescriptor, "r")
        while stdin_file == nil {
            stdin_pipe = Pipe()
            stdin_file = fdopen(stdin_pipe.fileHandleForReading.fileDescriptor, "r")
        }
        stdin_file_input = stdin_pipe.fileHandleForWriting

        var stdout_pipe = Pipe()
        stdout_file = fdopen(stdout_pipe.fileHandleForWriting.fileDescriptor, "w")
        while stdout_file == nil {
            stdout_pipe = Pipe()
            stdout_file = fdopen(stdout_pipe.fileHandleForWriting.fileDescriptor, "w")
        }
        stdout_pipe.fileHandleForReading.readabilityHandler = self.onStdout

        stdout_active = true

        let queue = DispatchQueue(label: "\(command)", qos: .utility)

        queue.async {
            if isInteractive {
                self.state = .interactive
            } else {
                self.state = .running
            }

            ios_setDirectoryURL(self.currentWorkingDirectory)
            self.lastCommand = command
            Thread.current.name = command

            ios_switchSession(self.persistentIdentifier.toCString())
            ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier.toCString()))
            ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)

            let code = self.run(command: command)

            close(stdin_pipe.fileHandleForReading.fileDescriptor)
            self.stdin_file_input = nil

            // Send info to the stdout handler that the command has finished:
            let writeOpen = fcntl(stdout_pipe.fileHandleForWriting.fileDescriptor, F_GETFD)
            if writeOpen >= 0 {
                // Pipe is still open, send information to close it, once all output has been processed.
                stdout_pipe.fileHandleForWriting.write(self.END_OF_TRANSMISSION.data(using: .utf8)!)
                while self.stdout_active {
                    fflush(thread_stdout)
                }
            }

            close(stdout_pipe.fileHandleForReading.fileDescriptor)

            DispatchQueue.main.async {
                self.state = .idle
            }

            var url = URL(fileURLWithPath: FileManager().currentDirectoryPath)

            // Sometimes pip would change the working directory to an inaccesible location,
            // we need to verify that the current directory is readable.
            if (try? FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: nil)) == nil
            {
                url = self.currentWorkingDirectory
            }

            ios_setMiniRootURL(url)

            DispatchQueue.main.async {
                self.prompt =
                    "\(FileManager().currentDirectoryPath.split(separator: "/").last?.removingPercentEncoding ?? "") $ "
                self.currentWorkingDirectory = url
            }

            completionHandler(code)
        }
    }

    private func run(command: String) -> Int32 {
        NSLog("Running command: \(command)")

        // ios_system requires these to be set to nil before command execution
        thread_stdin = nil
        thread_stdout = nil
        thread_stderr = nil

        pid = ios_fork()
        let returnCode = ios_system(command)
        ios_waitpid(pid!)
        ios_releaseThreadId(pid!)
        pid = nil

        // Flush pipes to make sure all data is read
        fflush(thread_stdout)
        fflush(thread_stderr)

        return returnCode
    }
}
