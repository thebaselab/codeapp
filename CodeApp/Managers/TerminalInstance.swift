//
//  TerminalInstance.swift
//  Code
//
//  Created by Ken Chung on 8/6/2021.
//

import SwiftUI
import WebKit
import ios_system

struct TerminalOptions: Codable {
    var fontSize: Int = 14
    var fontFamily: String = "Menlo"
    var toolbarEnabled: Bool = true
    var shouldShowCompilerPath: Bool = false

    // subsequent options must be made optional
}

class TerminalInstance: NSObject, WKScriptMessageHandler, WKNavigationDelegate, Identifiable {

    let id: UUID
    var name: String
    private(set) var isReady = false

    var options: TerminalOptions {
        didSet {
            configureCustomOptions()
        }
    }

    let INTERRUPT = "\u{03}"
    let END_OF_TRANSMISSION = "\u{04}"

    public var terminalServiceProvider: TerminalServiceProvider? = nil {
        didSet {
            if terminalServiceProvider != nil {
                self.startInteractive()
            }
            if terminalServiceProvider == nil && oldValue != nil {
                self.stopInteractive()
                self.clearLine()
            }
        }
    }
    public var webView: WebViewBase = WebViewBase()
    public var executor: Executor? = nil
    private var terminalMessageHandlerAdded = false
    public var openEditor: ((URL) -> Void)? = nil

    var isInteractive = false

    func blur() {
        executeScript("document.getElementById('overlay').focus()")
    }

    func sendInterrupt() {
        executeScript("sendInterrupt()")
    }

    func startInteractive() {
        if !isInteractive {
            isInteractive = true
            executeScript("startInteractive()")
        }
    }

    func stopInteractive() {
        if isInteractive {
            isInteractive = false
            executeScript("stopInteractive()")
        }
    }

    func setFontSize(size: Int) {
        executeScript("term.options.fontSize = \(size)")
    }

    private func applyFont(fontFamily: String) {
        guard
            let percentEncoded = fontFamily.addingPercentEncoding(
                withAllowedCharacters: .urlPathAllowed)
        else {
            return
        }
        let js = """
            var styles = `
                @font-face {
                font-family: "\(fontFamily)";
                src: local("\(fontFamily)"),
                  url("fonts://\(percentEncoded).ttf") format("truetype");
              }
            `
            var styleSheet = document.createElement("style")
            styleSheet.innerHTML = styles
            document.head.appendChild(styleSheet)
            """
        executeScript(js)
        executeScript("term.options.fontFamily = '\(fontFamily)'")
    }

    private func configureCustomOptions() {
        executeScript("term.options.fontSize = \(String(options.fontSize))")
        applyFont(fontFamily: options.fontFamily)
    }

    func resetAndSetNewRootDirectory(url: URL) {
        executor?.setNewWorkingDirectory(url: url)
        guard let prompt = executor?.prompt else {
            return
        }
        executeScript("localEcho._activePrompt.prompt = `\(prompt)`")
        reset()
    }

    func clearLine() {
        guard let prompt = executor?.prompt else {
            return
        }
        let newline = #"\r\n"#
        self.executeScript("term.write('\(newline)');readLine('\(prompt)');")
    }

    func reset() {
        guard terminalServiceProvider == nil else {
            return
        }
        guard !isInteractive, let prompt = executor?.prompt else {
            return
        }
        self.executeScript(#"term.write('\033c"# + "\(prompt)' + localEcho._input)")
    }

    func applyTheme(rawTheme: [String: Any]) {
        guard let colorArray = rawTheme["colors"] as? [String: String] else {
            return
        }
        var outputTheme: [String: String] = [:]

        outputTheme["background"] =
            colorArray["terminal.background"] ?? colorArray["editor.background"]
            ?? (rawTheme["type"] as? String == "dark" ? "#1e1e1e" : "#EBEBEB")
        outputTheme["black"] = colorArray["terminal.ansiBlack"]
        outputTheme["blue"] = colorArray["terminal.ansiBlue"]
        outputTheme["brightBlack"] = colorArray["terminal.ansiBrightBlack"]
        outputTheme["brightBlue"] = colorArray["terminal.ansiBrightBlue"]
        outputTheme["brightCyan"] = colorArray["terminal.ansiBrightCyan"]
        outputTheme["brightGreen"] = colorArray["terminal.ansiBrightGreen"]
        outputTheme["brightMagenta"] = colorArray["terminal.ansiBrightMagenta"]
        outputTheme["brightRed"] = colorArray["terminal.ansiBrightRed"]
        outputTheme["brightWhite"] = colorArray["terminal.ansiBrightWhite"]
        outputTheme["brightYellow"] = colorArray["terminal.ansiBrightYellow"]
        outputTheme["cursor"] =
            colorArray["terminalCursor.foreground"]
            ?? (rawTheme["type"] as? String == "dark" ? "#ffffff" : "#000000")
        outputTheme["cursorAccent"] = colorArray["terminalCursor.background"]
        outputTheme["cyan"] = colorArray["terminal.ansiBrightCyan"]
        outputTheme["foreground"] =
            colorArray["terminal.foreground"] ?? colorArray["editor.foreground"]
            ?? (rawTheme["type"] as? String == "dark" ? "#ffffff" : "#1e1e1e")
        outputTheme["green"] = colorArray["terminal.ansiGreen"]
        outputTheme["magenta"] = colorArray["terminal.ansiMagenta"]
        outputTheme["red"] = colorArray["terminal.ansiRed"]
        outputTheme["selection"] = colorArray["terminal.selectionBackground"]
        outputTheme["white"] = colorArray["terminal.ansiWhite"]
        outputTheme["yellow"] = colorArray["terminal.ansiYellow"]

        if let theJSONData = try? JSONSerialization.data(
            withJSONObject: outputTheme, options: .prettyPrinted),
            let jsonText = String(data: theJSONData, encoding: .utf8),
            let type = rawTheme["type"] as? String
        {
            setTheme(base64encoded: jsonText.base64Encoded()!, isDark: type == "dark")
        }

    }

    private func setTheme(base64encoded: String, isDark: Bool) {
        executeScript("applyBase64AsTheme('\(base64encoded)', \(isDark ? "true" : "false"))")
    }

    func executeScript(_ script: String) {
        DispatchQueue.main.async {
            self.webView.evaluateJavaScript(script) { (result, error) in
                if result != nil { print(result as Any) }
                if error != nil { print(error as Any) }
            }
        }
    }

    func readLine() {
        guard let prompt = executor?.prompt else {
            return
        }
        executeScript("readLine('\(prompt)')")
    }

    private func openSharedFilesApp(urlString: String) {
        let sharedurl = urlString.replacingOccurrences(of: "file://", with: "shareddocuments://")
        if let furl: URL = URL(string: sharedurl) {
            UIApplication.shared.open(furl, options: [:], completionHandler: nil)
        }
    }

    // WKWebView Delegates
    func webView(
        _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.targetFrame == nil {
            if let url = navigationAction.request.url {
                UIApplication.shared.open(url)
            }
        }
        decisionHandler(.allow)
    }

    func userContentController(
        _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
        guard let result = message.body as? [String: AnyObject] else { return }
        guard let event = result["Event"] as? String else { return }

        if let ts = self.terminalServiceProvider {
            startInteractive()

            switch event {
            case "window.size.change":
                let cols = result["Cols"] as! Int
                let rows = result["Rows"] as! Int
                if let ts = terminalServiceProvider {
                    ts.setWindowsSize(cols: cols, rows: rows)
                }
            case "Data":
                if let input = result["Input"] as? String {
                    ts.write(data: "\(input)".data(using: .utf8)!)
                }
            case "ControlReset":
                let generation = result["Generation"] as? Int ?? 0
                NotificationCenter.default.post(
                    name: .terminalControlReset,
                    object: self,
                    userInfo: ["generation": generation]
                )
            case "AltReset":
                let generation = result["Generation"] as? Int ?? 0
                NotificationCenter.default.post(
                    name: .terminalAltReset,
                    object: self,
                    userInfo: ["generation": generation]
                )
            default:
                return
            }
            return
        }

        if self.executor?.state == .interactive {
            switch event {
            case "Data":
                self.executor?.sendInput(input: result["Input"] as! String)
            case "ControlReset":
                let generation = result["Generation"] as? Int ?? 0
                NotificationCenter.default.post(
                    name: .terminalControlReset,
                    object: self,
                    userInfo: ["generation": generation]
                )
            case "AltReset":
                let generation = result["Generation"] as? Int ?? 0
                NotificationCenter.default.post(
                    name: .terminalAltReset,
                    object: self,
                    userInfo: ["generation": generation]
                )
            default:
                break
            }
            return
        }

        if self.executor?.state == .running && event == "Return" {
            self.executor?.sendInput(input: result["Input"] as! String)
            return
        }

        switch event {
        case "Return":
            switch result["Input"] as! String {
            case "help":
                let messages = [
                    "Code App's emulated terminal is built on top of Nicolas Holzschuch (GitHub: holzschu)'s ios_system. It has many Unix commands: ls, pwd, tar, mkdir, grep... You can redirect command output to a file with \">\" and pipe commands with \"|\". In addition, there is support for Node.js and Python runtime.",
                    "\n",
                    "- Install packages with pip and npm (not all modules work on iOS)",
                    "- Run scripts with python and node",
                    "\n",
                    "- File Transfering: curl, tar, scp and sftp",
                    "- Network queries: nslookup, pink, host, whois, ifconfig...",
                    "\n",
                    "For a full list of commands, press tab or type help -l",
                ]
                for line in messages {
                    executeScript("localEcho.println(`\(line)`);")
                }
                self.readLine()
            case "help -l":
                var commandList = [String]()
                for i in commandsAsArray() {
                    commandList.append(i as! String)
                }
                // Python bin
                let pythonBin = try! FileManager().url(
                    for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true
                ).appendingPathComponent("bin")
                if let commands = try? FileManager.default.contentsOfDirectory(
                    atPath: pythonBin.path)
                {
                    commandList += commands
                }
                executeScript("localEcho.printWide(\(commandList));")
                self.readLine()
            case let x where x.hasPrefix("git"):
                let message = "git is unavailable in Code App. Use lg2 instead."
                executeScript("localEcho.println(`\(message)`);")
                self.readLine()
            case let x where x.hasPrefix("code"):
                let args = x.components(separatedBy: " ")
                guard args.count > 1 else {
                    executeScript("localEcho.println(`Usage: code <file>`)")
                    self.readLine()
                    return
                }
                guard
                    let fileUrl = self.executor?.currentWorkingDirectory.appendingPathComponent(
                        String(
                            x.dropFirst(5).replacingOccurrences(of: #"\ "#, with: " ")
                                .trimmingCharacters(in: .whitespacesAndNewlines))),
                    FileManager.default.fileExists(atPath: fileUrl.path)
                else {
                    executeScript(
                        "localEcho.println(`File '\(String(x.dropFirst(5)).replacingOccurrences(of: #"\ "#, with: " ").trimmingCharacters(in: .whitespacesAndNewlines))' does not exist.`)"
                    )
                    self.readLine()
                    return
                }
                openEditor?(fileUrl)
                self.readLine()
            case "clear":
                self.executeScript("localEcho._input='';" + #"term.write('\033c')"#)
                self.readLine()
            case "files":
                guard let dir = self.executor?.currentWorkingDirectory.absoluteString else {
                    return
                }
                openSharedFilesApp(urlString: dir)
                self.readLine()
            default:
                let command = result["Input"] as! String
                //                guard command.count > 0 else {
                //                    return
                //                }
                let isInteractive = command.hasPrefix("ssh ") || command.hasPrefix("sftp")
                if isInteractive {
                    startInteractive()
                }
                executor?.dispatch(command: command, isInteractive: isInteractive) { _ in
                    DispatchQueue.main.async {
                        if self.isInteractive {
                            self.stopInteractive()
                        }
                        self.readLine()
                    }
                }
            }
        case "Init":
            guard executor != nil else {
                fatalError("Executor has not been initialized")
            }
            self.readLine()

            if var lightTheme = ThemeManager.lightTheme {
                self.applyTheme(rawTheme: lightTheme.dictionary)
            }
            if var darkTheme = ThemeManager.darkTheme {
                self.applyTheme(rawTheme: darkTheme.dictionary)
            }
            configureCustomOptions()
            isReady = true
            NotificationCenter.default.post(name: .terminalDidInitialize, object: self)
        case "window.size.change":
            let cols = result["Cols"] as! Int
            let rows = result["Rows"] as! Int
            executor?.setWindowSize(cols: cols, rows: rows)
        case "Data":
            let data = result["Input"] as! String

            if data == END_OF_TRANSMISSION {
                executor?.endOfTransmission()
            }

            if data == INTERRUPT {
                if executor?.state == .idle {
                    clearLine()
                } else {
                    executor?.kill()
                }
            }
        case "ControlReset":
            let generation = result["Generation"] as? Int ?? 0
            NotificationCenter.default.post(
                name: .terminalControlReset,
                object: self,
                userInfo: ["generation": generation]
            )
        case "AltReset":
            let generation = result["Generation"] as? Int ?? 0
            NotificationCenter.default.post(
                name: .terminalAltReset,
                object: self,
                userInfo: ["generation": generation]
            )
        default:
            print("\(result) Event not handled")
        }
    }

    func write(data: Data) {
        self.executeScript(
            "term.write(base64ToString('\(data.base64EncodedString())'));")
    }

    private func writeToLocalTerminal(data: Data) {
        let str = String(decoding: data, as: UTF8.self)
        DispatchQueue.main.async {
            if self.isInteractive || str.contains("\u{8}") || str.contains("\u{13}")
                || str.contains("\r")
            {
                self.executeScript(
                    "term.write(base64ToString('\(str.base64Encoded()!)'));")
            } else {
                self.executeScript(
                    "localEcho.print(base64ToString('\(str.base64Encoded()!)'));")
            }
        }
    }

    init(root: URL, options: TerminalOptions, name: String = "Terminal", id: UUID = UUID()) {
        self.id = id
        self.name = name
        self.options = options
        super.init()
        self.executor = Executor(
            root: root,
            sessionIdentifier: "com.thebaselab.terminal.\(id.uuidString)",
            onStdout: { [weak self] data in
                self?.writeToLocalTerminal(data: data)
            },
            onStderr: { [weak self] data in
                self?.writeToLocalTerminal(data: data)
            },
            onRequestInput: { [weak self] prompt in
                let prompt = prompt.replacingOccurrences(of: "\n", with: "\r\n")
                DispatchQueue.main.async {
                    self?.executeScript("readLine(base64ToString('\(prompt.base64Encoded()!)'))")
                }
            })

        webView.uiDelegate = self
        webView.isOpaque = false
        webView.navigationDelegate = self
        webView.customUserAgent =
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Safari/605.1.15"
        if !terminalMessageHandlerAdded {
            if let bundlePath = Bundle.main.path(forResource: "terminal", ofType: "bundle"),
                let bundle = Bundle(path: bundlePath),
                let url = bundle.url(forResource: "index", withExtension: "html")
            {
                webView.loadFileURL(url, allowingReadAccessTo: url)
                let request = URLRequest(url: url)
                webView.load(request)
            }
            let contentManager = webView.configuration.userContentController
            terminalMessageHandlerAdded = true
            contentManager.add(self, name: "toggleMessageHandler2")
        }
    }

}

extension TerminalInstance: WKUIDelegate {
    func webView(
        _ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?, initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        switch prompt {
        case "autocomplete.currentdir":
            do {
                guard var currentDir = executor?.currentWorkingDirectory else {
                    return
                }
                if defaultText != nil {
                    var components = defaultText!.components(separatedBy: "/")
                    components = components.dropLast()
                    let path = components.joined(separator: "/")
                    currentDir.appendPathComponent(path)
                }
                let items = try FileManager.default.contentsOfDirectory(
                    at: currentDir, includingPropertiesForKeys: nil)
                var names = [String]()
                for item in items {
                    if item.hasDirectoryPath {
                        names.append(
                            item.lastPathComponent.replacingOccurrences(of: " ", with: #"\ "#) + "/"
                        )
                    } else {
                        names.append(
                            item.lastPathComponent.replacingOccurrences(of: " ", with: #"\ "#))
                    }
                }
                completionHandler("\(names)")
            } catch {
                completionHandler("[]")
            }
        case "autocomplete.commands":
            var commandList = [String]()
            for i in commandsAsArray() {
                commandList.append(i as! String)
            }
            // Python bin
            let pythonBin = try! FileManager().url(
                for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            ).appendingPathComponent("bin")
            if let commands = try? FileManager.default.contentsOfDirectory(atPath: pythonBin.path) {
                commandList += commands
            }
            commandList += ["help", "code"]
            completionHandler("\(commandList)")
        default:
            print("\(prompt) not handled")
        }
    }
}

// Cleanup method

extension TerminalInstance {
    /// Cleans up resources before the terminal is deallocated.
    /// Call this method before removing the terminal from TerminalManager.
    func cleanup() {
        if executor?.state != .idle {
            executor?.kill()
        }
        terminalServiceProvider?.kill()
        terminalServiceProvider = nil
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.removeFromSuperview()
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
        executor = nil
        openEditor = nil
    }
}

// Keyboard toolbar methods

extension TerminalInstance {
    func type(text: String) {
        guard let base64 = text.base64Encoded() else { return }
        executeScript("inputWithModifiers(base64ToString(`\(base64)`))")
    }

    func moveCursor(codeSequence: String) {
        executeScript("inputWithModifiers(String.fromCharCode(0x1b)+'\(codeSequence)')")
    }

    func setControlActive(_ active: Bool, generation: Int) {
        executeScript("setControlActive(\(active), \(generation))")
    }

    func setControlLocked(_ locked: Bool) {
        executeScript("setControlLocked(\(locked))")
    }

    func setAltActive(_ active: Bool, generation: Int) {
        executeScript("setAltActive(\(active), \(generation))")
    }

    func setAltLocked(_ locked: Bool) {
        executeScript("setAltLocked(\(locked))")
    }
}

extension Notification.Name {
    static let terminalControlReset = Notification.Name("terminalControlReset")
    static let terminalAltReset = Notification.Name("terminalAltReset")
    static let terminalDidInitialize = Notification.Name("terminalDidInitialize")
}
