//
//  wasm.swift
//  Code
//  https://github.com/holzschu/a-shell/blob/master/a-Shell/SceneDelegate.swift
//

import Foundation
import WebKit
import ios_system

@_cdecl("wasm")
public func wasm(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let args = convertCArguments(argc: argc, argv: argv)
    return executeWebAssembly(arguments: args)
}

class wasmWebViewDelegate: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
    func fileDescriptor(input: String) -> Int32? {
        guard let fd = Int32(input) else {
            return nil
        }
        if fd == 0 {
            return fileno(thread_stdin_copy)
        }
        if fd == 1 {
            return fileno(thread_stdout_copy)
        }
        if fd == 2 {
            return fileno(thread_stderr_copy)
        }
        return fd
    }

    func userContentController(
        _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
        guard let cmd: String = message.body as? String else {
            // NSLog("Could not convert Javascript message: \(message.body)")
            return
        }
        // Make sure we're acting on the right session here:
        if cmd.hasPrefix("print:") {
            // print result of JS file:
            var string = cmd
            string.removeFirst("print:".count)
            if thread_stdout_copy != nil {
                fputs(string, thread_stdout_copy)
            }
        } else if cmd.hasPrefix("print_error:") {
            // print result of JS file:
            var string = cmd
            string.removeFirst("print_error:".count)
            if thread_stderr_copy != nil {
                fputs(string, thread_stderr_copy)
            }
        } else {
            // Usually debugging information
            // NSLog("JavaScript message: \(message.body)")
            print("JavaScript message: \(message.body)")
        }
    }

    func webView(
        _ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?, initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        // communication with libc from webAssembly:

        let arguments = prompt.components(separatedBy: "\n")
        // NSLog("prompt: \(prompt)")
        let title = arguments[0]
        if title == "libc" {
            // Make sure we are on the right iOS session. This resets the current working directory.
            ios_switchSession("wasm")
            ios_setContext(UnsafeMutableRawPointer(mutating: "wasm".toCString()))
            if arguments[1] == "open" {
                let rights = Int32(arguments[3]) ?? 577
                if !FileManager().fileExists(atPath: arguments[2]) && (rights > 0) {
                    // The file doesn't exist *and* we will want to write into it. First, we create it:
                    let fileUrl = URL(fileURLWithPath: arguments[2])
                    do {
                        try "".write(to: fileUrl, atomically: true, encoding: .utf8)
                    } catch {
                        // We will raise an error with open later.
                    }
                }
                let returnValue = open(arguments[2], rights)
                if returnValue == -1 {
                    completionHandler("\(-errno)")
                    errno = 0
                } else {
                    completionHandler("\(returnValue)")
                }
                return
            } else if arguments[1] == "close" {
                var returnValue: Int32 = -1
                if let fd = fileDescriptor(input: arguments[2]) {
                    if (fd == fileno(thread_stdin_copy)) || (fd == fileno(thread_stdout_copy))
                        || (fd == fileno(thread_stdout_copy))
                    {
                        // don't close stdin/stdout/stderr
                        returnValue = 0
                    } else {
                        returnValue = close(fd)
                    }
                    if returnValue == -1 {
                        completionHandler("\(-errno)")
                        errno = 0
                    } else {
                        completionHandler("\(returnValue)")
                    }
                    return
                }
                completionHandler("\(-EBADF)")  // invalid file descriptor
                return
            } else if arguments[1] == "write" {
                var returnValue = Int(-EBADF)  // Number of bytes written
                if let fd = fileDescriptor(input: arguments[2]) {
                    // arguments[3] == "84,104,105,115,32,116,101,120,116,32,103,111,101,115,32,116,111,32,115,116,100,111,117,116,10"
                    // arguments[4] == nb bytes
                    // arguments[5] == offset
                    returnValue = 0  // valid file descriptor, maybe nothing to write
                    // Do we have something to write?
                    if (arguments.count >= 6) && (arguments[3].count > 0) {
                        let values = arguments[3].components(separatedBy: ",")
                        var data = Data.init()
                        if let numValues = Int(arguments[4]) {
                            if numValues > 0 {
                                let offset = UInt64(arguments[5]) ?? 0
                                for c in 0...numValues - 1 {
                                    if let value = UInt8(values[c]) {
                                        data.append(contentsOf: [value])
                                    }
                                }
                                // let returnValue = write(fd, data, numValues)
                                let file = FileHandle(fileDescriptor: fd)
                                if offset > 0 {
                                    do {
                                        try file.seek(toOffset: offset)
                                    } catch {
                                        let errorCode = (error as NSError).code
                                        completionHandler("\(-errorCode)")
                                        return
                                    }
                                }
                                file.write(data)
                                returnValue = numValues
                            }
                        }
                    }
                }
                completionHandler("\(returnValue)")
                return
            } else if arguments[1] == "read" {
                var data: Data?
                if let fd = fileDescriptor(input: arguments[2]) {
                    // arguments[3] = length
                    // arguments[4] = offset
                    // arguments[5] = tty input
                    // let values = arguments[3].components(separatedBy:",")
                    if let numValues = Int(arguments[3]) {
                        let offset = UInt64(arguments[4]) ?? 0
                        let file = FileHandle(fileDescriptor: fd)
                        let isTTY = Int(arguments[5]) ?? 0
                        if (fd == fileno(thread_stdin_copy)) && (isTTY != 0) {
                            // Reading from stdin is delicate, we must avoid blocking the UI.
                            var inputString = stdinString
                            if inputString.count > numValues {
                                inputString = String(stdinString.prefix(numValues))
                                stdinString.removeFirst(numValues)
                            } else {
                                stdinString = ""
                            }
                            let utf8str = inputString.data(using: .utf8)
                            if utf8str == nil {
                                completionHandler("")
                            } else {
                                completionHandler(
                                    "\(utf8str!.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0)))"
                                )
                            }
                            return
                        } else {
                            do {
                                try file.seek(toOffset: offset)
                            } catch {
                                if offset != 0 {
                                    let errorCode = (error as NSError).code
                                    completionHandler("\(-errorCode)")
                                    return
                                }
                            }
                            do {
                                try data = file.read(upToCount: numValues)
                            } catch {
                            }
                        }
                    }
                    if data != nil {
                        completionHandler("\(data!.base64EncodedString())")
                    } else {
                        completionHandler("")  // Did not read anything
                    }
                } else {
                    completionHandler("\(-EBADF)")  // Invalid file descriptor
                }
                return
            } else if arguments[1] == "fstat" {
                if let fd = fileDescriptor(input: arguments[2]) {
                    let buf = stat.init()
                    let pbuf = UnsafeMutablePointer<stat>.allocate(capacity: 1)
                    pbuf.initialize(to: buf)
                    let returnValue = fstat(fd, pbuf)
                    if returnValue == 0 {
                        completionHandler("\(pbuf.pointee)")
                    } else {
                        completionHandler("\(-errno)")
                        errno = 0
                    }
                    return
                }
                completionHandler("\(-EBADF)")  // Invalid file descriptor
                return
            } else if arguments[1] == "stat" {
                let buf = stat.init()
                let pbuf = UnsafeMutablePointer<stat>.allocate(capacity: 1)
                pbuf.initialize(to: buf)
                let returnValue = stat(arguments[2], pbuf)
                if returnValue == 0 {
                    completionHandler("\(pbuf.pointee)")
                } else {
                    completionHandler("\(-errno)")
                    errno = 0
                }
                return
            } else if arguments[1] == "readdir" {
                do {
                    // Much more compact code than using readdir.
                    let items = try FileManager().contentsOfDirectory(atPath: arguments[2])
                    var returnString = ""
                    for item in items {
                        returnString = returnString + item + "\n"
                    }
                    completionHandler(returnString)
                } catch {
                    let errorCode = (error as NSError).code
                    completionHandler("\(-errorCode)")
                }
                return
            } else if arguments[1] == "mkdir" {
                do {
                    try FileManager().createDirectory(
                        atPath: arguments[2], withIntermediateDirectories: true)
                    completionHandler("0")
                } catch {
                    let errorCode = (error as NSError).code
                    completionHandler("\(-errorCode)")
                }
                return
            } else if arguments[1] == "rmdir" {
                do {
                    try FileManager().removeItem(atPath: arguments[2])
                    completionHandler("0")
                } catch {
                    let errorCode = (error as NSError).code
                    completionHandler("\(-errorCode)")
                }
                return
            } else if arguments[1] == "rename" {
                do {
                    try FileManager().moveItem(atPath: arguments[2], toPath: arguments[3])
                    completionHandler("0")
                } catch {
                    let errorCode = (error as NSError).code
                    completionHandler("\(-errorCode)")
                }
                return
            } else if arguments[1] == "link" {
                do {
                    try FileManager().linkItem(atPath: arguments[2], toPath: arguments[3])
                    completionHandler("0")
                } catch {
                    let errorCode = (error as NSError).code
                    completionHandler("\(-errorCode)")
                }
                return
            } else if arguments[1] == "symlink" {
                do {
                    try FileManager().createSymbolicLink(
                        atPath: arguments[3], withDestinationPath: arguments[2])
                    completionHandler("0")
                } catch {
                    let errorCode = (error as NSError).code
                    completionHandler("\(-errorCode)")
                }
                return
            } else if arguments[1] == "readlink" {
                do {
                    let destination = try FileManager().destinationOfSymbolicLink(
                        atPath: arguments[2])
                    completionHandler(destination)
                } catch {
                    // to remove ambiguity, add '\n' at the beginning
                    // this might fail if a link points to
                    let errorCode = (error as NSError).code
                    completionHandler("\n\(-errorCode)")
                }
                return
            } else if arguments[1] == "unlink" {
                let returnVal = unlink(arguments[2])
                if returnVal != 0 {
                    completionHandler("\(-errno)")
                    errno = 0
                } else {
                    completionHandler("\(returnVal)")
                }
                return
            } else if arguments[1] == "fsync" {
                if let fd = fileDescriptor(input: arguments[2]) {
                    let returnVal = fsync(fd)
                    if returnVal != 0 {
                        completionHandler("\(-errno)")
                        errno = 0
                    } else {
                        completionHandler("\(returnVal)")
                    }
                    return
                }
                completionHandler("\(-EBADF)")  // invalid file descriptor
                return
            } else if arguments[1] == "ftruncate" {
                if let fd = fileDescriptor(input: arguments[2]) {
                    if let length = Int64(arguments[3]) {
                        let returnVal = ftruncate(fd, length)
                        if returnVal != 0 {
                            completionHandler("\(-errno)")
                            errno = 0
                        } else {
                            completionHandler("\(returnVal)")
                        }
                        return
                    }
                    completionHandler("\(-EINVAL)")  // invalid length
                    return
                }
                completionHandler("\(-EBADF)")  // invalid file descriptor
                return
                //
                // Additions to WASI for easier interaction with the iOS underlying part: getenv, setenv, unsetenv
                // getcwd, chdir, fchdir, system.
                //
            } else if arguments[1] == "getcwd" {
                let result = FileManager().currentDirectoryPath
                completionHandler(result)
                return
            } else if arguments[1] == "chdir" {
                // true or false
                completionHandler("\(FileManager.default.changeCurrentDirectoryPath(arguments[2]))")
                return
            } else if arguments[1] == "fchdir" {
                if let fd = Int32(arguments[2]) {
                    let result = fchdir(fd)
                    if result != 0 {
                        completionHandler("\(-errno)")
                        errno = 0
                    } else {
                        completionHandler("\(result)")
                    }
                } else {
                    completionHandler("-\(EBADF)")  // bad file descriptor
                }
                return
            } else if arguments[1] == "system" {
                thread_stdin = thread_stdin_copy
                thread_stdout = thread_stdout_copy
                thread_stderr = thread_stdout_copy
                let pid = ios_fork()
                let result = ios_system(arguments[2])
                ios_waitpid(pid)
                completionHandler("\(result)")
                return
            } else if arguments[1] == "getenv" {
                let result = ios_getenv(arguments[2])
                if result != nil {
                    completionHandler(String(cString: result!))
                } else {
                    completionHandler("0")
                }
                return
            } else if arguments[1] == "setenv" {
                let force = Int32(arguments[4])
                let result = setenv(arguments[2], arguments[3], force!)
                if result != 0 {
                    completionHandler("\(-errno)")
                    errno = 0
                } else {
                    completionHandler("\(result)")
                }
                return
            } else if arguments[1] == "unsetenv" {
                let result = unsetenv(arguments[2])
                if result != 0 {
                    completionHandler("\(-errno)")
                    errno = 0
                } else {
                    completionHandler("\(result)")
                }
                return
            } else if arguments[1] == "utimes" {
                let path = arguments[2]
                if let atime_sec = Int(arguments[3]) {
                    var atime_usec = Int32(arguments[4])
                    if atime_usec == nil {
                        atime_usec = 0
                    } else {
                        atime_usec = atime_usec! / 1000
                    }
                    let atime: timeval = timeval(tv_sec: atime_sec, tv_usec: atime_usec!)
                    if let mtime_sec = Int(arguments[5]) {
                        var mtime_usec = Int32(arguments[6])
                        if mtime_usec == nil {
                            mtime_usec = 0
                        } else {
                            mtime_usec = mtime_usec! / 1000
                        }
                        let mtime: timeval = timeval(tv_sec: mtime_sec, tv_usec: mtime_usec!)
                        let time = UnsafeMutablePointer<timeval>.allocate(capacity: 2)
                        time[0] = atime
                        time[1] = mtime
                        let returnVal = utimes(path, time)
                        if returnVal != 0 {
                            completionHandler("\(-errno)")
                            errno = 0
                        } else {
                            completionHandler("\(returnVal)")
                        }
                        return
                    } else {
                        // time points out of process allocated space
                        completionHandler("\(-EFAULT)")
                        return
                    }
                } else {
                    // time points out of process allocated space
                    completionHandler("\(-EFAULT)")
                    return
                }
            } else if arguments[1] == "futimes" {
                if let fd = fileDescriptor(input: arguments[2]) {
                    if let atime_sec = Int(arguments[3]) {
                        var atime_usec = Int32(arguments[4])
                        if atime_usec == nil {
                            atime_usec = 0
                        } else {
                            atime_usec = atime_usec! / 1000
                        }
                        let atime: timeval = timeval(tv_sec: atime_sec, tv_usec: atime_usec!)
                        if let mtime_sec = Int(arguments[5]) {
                            var mtime_usec = Int32(arguments[6])
                            if mtime_usec == nil {
                                mtime_usec = 0
                            } else {
                                mtime_usec = mtime_usec! / 1000
                            }
                            let mtime: timeval = timeval(tv_sec: mtime_sec, tv_usec: mtime_usec!)
                            let time = UnsafeMutablePointer<timeval>.allocate(capacity: 2)
                            time[0] = atime
                            time[1] = mtime
                            let returnVal = futimes(fd, time)
                            if returnVal != 0 {
                                completionHandler("\(-errno)")
                                errno = 0
                            } else {
                                completionHandler("\(returnVal)")
                            }
                            return
                        } else {
                            completionHandler("\(-EFAULT)")
                            return
                        }
                    } else {
                        completionHandler("\(-EFAULT)")
                        return
                    }
                }
                completionHandler("\(-EBADF)")  // invalid file descriptor
                return
            }
            // Not one of our commands:
            completionHandler("-1")
            return
        }
        // End communication with webAssembly using libc
    }
}

private var wasmWebViewConfig: WKWebViewConfiguration {
    let config = WKWebViewConfiguration()
    config.preferences.javaScriptCanOpenWindowsAutomatically = true
    config.preferences.setValue(true as Bool, forKey: "allowFileAccessFromFileURLs")
    return config
}

class WasmWebView: WKWebView {
    init() {
        super.init(frame: .zero, configuration: wasmWebViewConfig)

        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences.setValue(true as Bool, forKey: "allowFileAccessFromFileURLs")

        self.isOpaque = false
        self.configuration.userContentController = WKUserContentController()

        let delegate = wasmWebViewDelegate()
        self.configuration.userContentController.add(delegate, name: "aShell")
        self.navigationDelegate = delegate
        self.uiDelegate = delegate
        self.isAccessibilityElement = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

var wasmWebView = WasmWebView()

var javascriptRunning = false  // We can't execute JS while we are already executing JS.

// copies of thread_std*, used when inside a sub-thread, for example executing webAssembly
private var thread_stdin_copy: UnsafeMutablePointer<FILE>? = nil
private var thread_stdout_copy: UnsafeMutablePointer<FILE>? = nil
private var thread_stderr_copy: UnsafeMutablePointer<FILE>? = nil
private var stdout_active = false
var stdinString: String = ""

private func executeWebAssembly(arguments: [String]?) -> Int32 {
    guard arguments != nil else { return -1 }
    guard arguments!.count >= 2 else { return -1 }  // There must be at least one command
    // copy arguments:
    let command = arguments![1]
    var argumentString = "["
    for c in 1...arguments!.count - 1 {
        if let argument = arguments?[c] {
            // replace quotes and backslashes in arguments:
            let sanitizedArgument = argument.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            argumentString = argumentString + " \"" + sanitizedArgument + "\","
        }
    }
    argumentString = argumentString + "]"
    // async functions don't work in WKWebView (so, no fetch, no WebAssembly.instantiateStreaming)
    // Instead, we load the file in swift and send the base64 version to JS
    let currentDirectory = FileManager().currentDirectoryPath
    let fileName = command.hasPrefix("/") ? command : currentDirectory + "/" + command
    guard let buffer = NSData(contentsOf: URL(fileURLWithPath: fileName)) else {
        fputs("wasm: file \(command) not found\n", thread_stderr)
        return -1
    }
    let localEnvironment = environmentAsArray()
    var environmentAsJSDictionary = "{"
    if localEnvironment != nil {
        for variable in localEnvironment! {
            if let envVar = variable as? String {
                // Let's not carry environment variables with quotes:
                if envVar.contains("\"") {
                    continue
                }
                let components = envVar.components(separatedBy: "=")
                if components.count == 0 {
                    continue
                }
                let name = components[0]
                var value = envVar
                value.removeFirst(name.count + 1)
                environmentAsJSDictionary += "\"" + name + "\"" + ":" + "\"" + value + "\",\n"
            }
        }
    }
    environmentAsJSDictionary += "}"
    let base64string = buffer.base64EncodedString()
    let javascript =
        "executeWebAssembly(\"\(base64string)\", " + argumentString + ", \"" + currentDirectory
        + "\", \(ios_isatty(STDIN_FILENO)), " + environmentAsJSDictionary + ")"
    if javascriptRunning {
        fputs(
            "We can't execute webAssembly while we are already executing webAssembly.",
            thread_stderr)
        return -1
    }
    javascriptRunning = true
    var errorCode: Int32 = 0
    thread_stdin_copy = thread_stdin
    thread_stdout_copy = thread_stdout
    thread_stderr_copy = thread_stderr
    DispatchQueue.main.async {
        wasmWebView.evaluateJavaScript(javascript) { (result, error) in
            if result != nil {
                // executeWebAssembly sends back stdout and stderr as two Strings:
                if let array = result! as? NSMutableArray {
                    if let code = array[0] as? Int32 {
                        // return value from program
                        errorCode = code
                    }
                    if let errorMessage = array[1] as? String {
                        // webAssembly compile error:
                        fputs(errorMessage, thread_stderr_copy)
                    }
                } else if let string = result! as? String {
                    fputs(string, thread_stdout_copy)
                }
            }
            javascriptRunning = false
        }
    }
    // force synchronization:
    while javascriptRunning {
        if thread_stdout != nil { fflush(thread_stdout) }
        if thread_stderr != nil { fflush(thread_stderr) }
        //        usleep(300000)
    }
    fputs("\n", thread_stdout_copy)
    //    usleep(300000) // 0.3 second
    return errorCode
}
