//
//  CloudCodeExecutionManager.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI
import ZIPFoundation

private struct CodeResult: Decodable {
    let status: CodeStatus
    let stdout: String?
    let stderr: String?
    let compile_output: String?
    let message: String?
    let exit_code: Int?
    let exit_signal: Int?
    let time: String?
    let memory: Float?
}

private struct CodeStatus: Decodable {
    let description: String
    let id: Int
}

enum PanelDisplayMode: Int {
    case input
    case output
    case split
}

class CloudCodeExecutionManager: ObservableObject {
    @Published var isRunningCode = false
    @Published var consoleContent = ""
    @Published var stdin: String = ""
    @Published var displayMode: PanelDisplayMode = .output

    private var mainSession: URLSession? = nil

    func stopRunning() {
        mainSession?.getTasksWithCompletionHandler {
            (dataTasks: Array, uploadTasks: Array, downloadTasks: Array) in
            for task in downloadTasks {
                task.cancel()
            }
            self.mainSession?.invalidateAndCancel()
        }

        DispatchQueue.main.async {
            self.isRunningCode = false
            self.consoleContent = "Execution cancelled."
        }

    }

    func runCode(directoryURL: URL, source: String, language: Int) {

        if JUDGE0_ENDPOINT.isEmpty {
            self.consoleContent = "Server-side execution is unsupported in TestFlight builds."
            return
        }

        self.isRunningCode = true

        self.consoleContent = "Running \(directoryURL.lastPathComponent) remotely..\n"

        var request = URLRequest(
            url: URL(
                string:
                    "\(JUDGE0_ENDPOINT)/submissions/?base64_encoded=true&wait=true"
            )!)
        request.httpMethod = "POST"

        let parameters: [String: Any] =
            language == 62
        ? generateJavaParameters(sourceURL: directoryURL, stdin: stdin)
            : [
                "source_code": source.base64Encoded()!,
                "language_id": language,
                "stdin": stdin.base64Encoded()!,
                "cpu_time_limit": 6,
                "additional_files": returnDirectoryAsBase64(
                    url: directoryURL.deletingLastPathComponent(), fileURL: directoryURL),
            ]

        do {
            request.httpBody = try JSONSerialization.data(
                withJSONObject: parameters, options: .prettyPrinted)
        } catch let error {
            print(error.localizedDescription)
        }

        request.addValue("application/json", forHTTPHeaderField: "content-Type")
        request.addValue("application/json", forHTTPHeaderField: "accept")
        request.addValue(JUDGE0_KEY, forHTTPHeaderField: "X-Auth-Token")

        mainSession = URLSession.shared

        mainSession?.dataTask(with: request) { data, response, err in
            guard self.isRunningCode else {
                return
            }
            if data != nil {
                DispatchQueue.main.async {
                    do {
                        let result = try JSONDecoder().decode(CodeResult.self, from: data!)

                        if result.stderr != nil {
                            self.consoleContent += "\n" + result.stderr!.base64Decoded()! + "\n"
                        }
                        if result.compile_output != nil {
                            if let mes = (result.compile_output!).base64Decoded() {
                                self.consoleContent += "\n" + mes + "\n"
                            }
                        }
                        if result.stdout != nil {
                            self.consoleContent += "\n" + result.stdout!.base64Decoded()! + "\n"
                        }
                        if result.time != nil && result.memory != nil {
                            self.consoleContent +=
                                "\nProgram finished in \(result.time!)s with \(result.memory!)KB of memory."
                        }
                        self.isRunningCode = false

                    } catch {
                        self.consoleContent.append("\nConnection failed.")
                        self.isRunningCode = false
                        print("Error info: \(error)")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.consoleContent.append("\nConnection failed.")
                    self.isRunningCode = false
                }

            }

        }.resume()

    }
}

private func generateJavaParameters(sourceURL: URL, stdin: String) -> [String: Any] {

    let archive = Archive(accessMode: .create)!

    do {
        try archive.addEntry(with: sourceURL.lastPathComponent, fileURL: sourceURL)

        let tempDir = FileManager().temporaryDirectory
        let compileFile = tempDir.appendingPathComponent("compile")
        let runFile = tempDir.appendingPathComponent("run")

        try "javac \(sourceURL.lastPathComponent)".write(
            to: compileFile, atomically: true, encoding: .utf8)
        try "java \(sourceURL.deletingPathExtension().lastPathComponent)".write(
            to: runFile, atomically: true, encoding: .utf8)

        try archive.addEntry(with: "compile", fileURL: compileFile)
        try archive.addEntry(with: "run", fileURL: runFile)
    } catch {
        return [:]
    }

    let base64 = archive.data!.base64EncodedString(options: .lineLength64Characters)

    let parameters: [String: Any] = [
        "language_id": 89,  // Multi-file program
        "stdin": stdin.base64Encoded()!,
        "cpu_time_limit": 6,
        "additional_files": base64,
    ]

    return parameters
}
