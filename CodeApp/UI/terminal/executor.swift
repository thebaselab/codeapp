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

    private var pid: pid_t? = nil
    private let stdin_pipe = Pipe()
    private let stdout_pipe = Pipe()
    private let stderr_pipe = Pipe()
    private let stdin_file: UnsafeMutablePointer<FILE>
    let stdout_file: UnsafeMutablePointer<FILE>
    private let stderr_file: UnsafeMutablePointer<FILE>

    private var stdin_file_input: FileHandle? = nil

    private var receivedStdout: ((_ data: Data) -> Void)
    private var receivedStderr: ((_ data: Data) -> Void)
    private var requestInput: ((_ prompt: String) -> Void)
    private var lastCommand: String? = nil

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
        initializeEnvironment()
        //        ios_setMiniRootURL(root)
        currentWorkingDirectory = root
        prompt = "\(root.lastPathComponent) $ "
        receivedStdout = onStdout
        receivedStderr = onStderr
        requestInput = onRequestInput

        // Get file for stdin that can be read from
        stdin_file = fdopen(stdin_pipe.fileHandleForReading.fileDescriptor, "r")
        // Get file for stdout/stderr that can be written to
        stdout_file = fdopen(stdout_pipe.fileHandleForWriting.fileDescriptor, "w")
        stderr_file = fdopen(stderr_pipe.fileHandleForWriting.fileDescriptor, "w")

        // Call the following functions when data is written to stdout/stderr.
        stdout_pipe.fileHandleForReading.readabilityHandler = self.onStdout
        stderr_pipe.fileHandleForReading.readabilityHandler = self.onStderr
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

    func kill() {
        guard self.state != .idle else {
            return
        }
        ios_switchSession(self.stdout_file)
        ios_kill()
        self.state = .idle
    }

    func sendInput(input: String) {
        guard self.state != .idle, let data = input.data(using: .utf8) else {
            return
        }

        // For wasm
        if state == .running {
            stdinString += input + "\n"
        }

        ios_switchSession(self.stdout_file)

        print(input.debugDescription)

        stdin_pipe.fileHandleForWriting.write(data)

        if state == .running {
            if let endData = "\n".data(using: .utf8) {
                stdin_pipe.fileHandleForWriting.write(endData)
            }
        }

    }

    private func onStdout(_ stdout: FileHandle) {
        let data = stdout.availableData
        DispatchQueue.main.async {
            if self.state == .running {
                let str = String(decoding: data, as: UTF8.self)
                print("out: #" + str.debugDescription + "#")
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

            ios_switchSession(self.stdout_file)
            ios_setStreams(self.stdin_file, self.stdout_file, self.stderr_file)
            let code = self.run(command: command)

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
        pid = ios_fork()
        let returnCode = ios_system(command)
        ios_waitpid(pid!)

        thread_stdout = nil
        thread_stderr = nil

        // Flush pipes to make sure all data is read
        fflush(thread_stdout)
        fflush(thread_stderr)

        return returnCode
    }
}
