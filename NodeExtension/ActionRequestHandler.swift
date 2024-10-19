//
//  ActionRequestHandler.swift
//  extension
//
//  Created by Ken Chung on 22/2/2021.
//

import CoreServices
import SwiftWS

func installNotificationObserver(){
    let notificationName = "com.thebaselab.code.node.stop" as CFString
    let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
    
    CFNotificationCenterAddObserver(notificationCenter, nil,
                                    { (
                                        center: CFNotificationCenter?,
                                        observer: UnsafeMutableRawPointer?,
                                        name: CFNotificationName?,
                                        object: UnsafeRawPointer?,
                                        userInfo: CFDictionary?
                                    ) in
                                        exit(0)
                                    },
                                    notificationName,
                                    nil,
                                    CFNotificationSuspensionBehavior.deliverImmediately)
}


class BinaryExecutor {
    let listener = OutputListener()
    let frameAdaptor = LSPFrameAdaptor()
    var needFrameAdaptor: Bool = false
    
    let constants = [
        "${JAVA_LSP_FAT_JAR_PATH}": Resources.javaLSP
    ]
    
    func writeToStdin(data: String){
        if needFrameAdaptor {
            frameAdaptor.receiveWebSocket(data: data)
        }else {
            listener.write(text: data)
        }
    }
    
    func executeBinary(
        args: [String],
        workingDirectory: URL,
        sharedFrameworksDirectory: URL,
        pythonLibraryDirectory: URL,
        redirectStderr: Bool,
        ws: SwiftWS.WebSocket,
        isLanguageService: Bool
    ){
        atexit {
            // Allow stdout to properly print before exit
            fflush(stdout)
            usleep(200000) // 0.2 seconds
        }
        
        var args = args
        args = args.map {
            if let replacement = constants[$0] {
                return replacement
            }else {
                return $0
            }
        }
        
        guard let executable = args.first else {
            return
        }
        
        self.needFrameAdaptor = isLanguageService
        
        frameAdaptor.onSendToWebSocket = { data in
            DispatchQueue.global(qos: .utility).async {
                ws.send(data)
            }
        }
        frameAdaptor.onWriteToStdin = { [weak self] data in
            self?.listener.write(text: data)
        }
        
        DispatchQueue.main.sync {
            FileManager.default.changeCurrentDirectoryPath(workingDirectory.path)
            
            self.listener.openConsolePipe()
            self.listener.onStdout = { text in
                if self.needFrameAdaptor {
                    self.frameAdaptor.receiveStdout(data: text)
                }else {
                    DispatchQueue.global(qos: .utility).async {
                        ws.send(text)
                    }
                }
            }
//            if !redirectStderr { return }
            self.listener.onStderr = { text in
                DispatchQueue.global(qos: .utility).async {
                    ws.send(text)
                }
            }
        }
        
        DispatchQueue.global(qos: isLanguageService ? .utility : .default).async {
            switch executable {
            case "java", "javac":
                JavaLauncher.shared.launchJava(args: args, frameworkDirectory: sharedFrameworksDirectory, currentDirectory: workingDirectory)
            case "node":
                NodeLauncher.shared.launchNode(args: args)
            default:
                SystemCommandLauncher.shared.launchSystemCommand(args: args, pythonLibraryDirectoryURL: pythonLibraryDirectory)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.listener.onStdout = nil
                self.listener.closeConsolePipe()
                ws.close(code: 1000, reason: "finished")
            }
        }
    }
}

class ActionRequestHandler: NSObject, NSExtensionRequestHandling {
    
    var wss: SwiftWS? = nil
    let queue = DispatchQueue(label: "extension.wss")
    var executing: Bool = false
    
    func beginRequest(with context: NSExtensionContext) {
        installNotificationObserver()
        
        guard wss == nil else {
            context.cancelRequest(withError: AppExtensionError.serverAlreadyStarted)
            return
        }
        
        var isStale = false
        guard let item = context.inputItems.first as? NSExtensionItem,
              let serverPort = item.userInfo?["port"] as? Int,
              let frameworkDirectoryBookmarkData = item.userInfo?["frameworksDirectoryBookmark"] as? Data,
              let frameworkDirectoryURL = try? URL(resolvingBookmarkData: frameworkDirectoryBookmarkData, bookmarkDataIsStale: &isStale),
              let pythonLibraryDirectoryBookmarkData = item.userInfo?["pythonLibraryDirectoryBookmark"] as? Data,
              let pythonLibraryDirectoryURL = try? URL(resolvingBookmarkData: pythonLibraryDirectoryBookmarkData, bookmarkDataIsStale: &isStale)
        else {
            context.cancelRequest(withError: AppExtensionError.missingServerConfiguration)
            return
        }
        _ = frameworkDirectoryURL.startAccessingSecurityScopedResource()
        _ = pythonLibraryDirectoryURL.startAccessingSecurityScopedResource()
        
        let wss = SwiftWS(port: serverPort, queue: queue)
        self.wss = wss
        
        let binaryExecutor = BinaryExecutor()
        
        wss.onConnection { ws, head in
            
            if self.executing {
                ws.send("extension service busy")
                ws.close(code: 4000, reason: "server busy")
            }
            
            ws.onMessage { message in
                if self.executing {
                   binaryExecutor.writeToStdin(data: message.data)
                }else {
                    let jsonData = message.data.data(using: .utf8)!
                    guard let request: ExecutionRequestFrame = try? JSONDecoder().decode(ExecutionRequestFrame.self, from: jsonData) else {
                        ws.send("malformed message")
                        return
                    }
                    
                    self.executing = true
                    
                    var workingDirectoryUrl: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    
                    if let workingDirectoryBookmark = request.workingDirectoryBookmark,
                       let workingDirectoryURL = try? URL(resolvingBookmarkData: workingDirectoryBookmark, bookmarkDataIsStale: &isStale){
                        _ = workingDirectoryURL.startAccessingSecurityScopedResource()
                        workingDirectoryUrl = workingDirectoryURL
                    }
                    
                    binaryExecutor.executeBinary(args: request.args, workingDirectory: workingDirectoryUrl, sharedFrameworksDirectory: frameworkDirectoryURL,
                                                 pythonLibraryDirectory: pythonLibraryDirectoryURL ,redirectStderr: request.redirectStderr, ws: message.target, isLanguageService: request.isLanguageService)
                }
            }
            
            ws.onClose { _ in
                wss.close()
                exit(0)
            }
        }
    }
}
