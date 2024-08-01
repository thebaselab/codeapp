//
//  ActionRequestHandler.swift
//  extension
//
//  Created by Ken Chung on 22/2/2021.
//

import CoreServices
import SwiftWS

class BinaryExecutor {
    let listener = OutputListener()
    
    func executeBinary(
        args: [String],
        workingDirectory: URL,
        sharedFrameworksDirectory: URL,
        ws: SwiftWS.WebSocket
    ){
        guard let executable = args.first else {
            return
        }
        
        DispatchQueue.main.sync {
            FileManager.default.changeCurrentDirectoryPath(workingDirectory.path)
            
            self.listener.openConsolePipe()
            self.listener.onStdout = { text in
                DispatchQueue.global(qos: .utility).async {
                    ws.send(text)
                }
            }
        }
        
        DispatchQueue.global(qos: .default).async {
            switch executable {
            case "java", "javac":
                JavaLauncher.shared.launchJava(args: args, frameworkDirectory: sharedFrameworksDirectory, currentDirectory: workingDirectory)
            case "node":
                NodeLauncher.shared.launchNode(args: args)
            default:
                break
            }
            
            self.listener.onStdout = nil
            self.listener.closeConsolePipe()
            
            usleep(200000)
            ws.close(code: 1000, reason: "finished")
        }
    }
}

class ActionRequestHandler: NSObject, NSExtensionRequestHandling {
    
    var wss: SwiftWS? = nil
    let queue = DispatchQueue(label: "extension.wss")
    var executing: Bool = false
    
    func beginRequest(with context: NSExtensionContext) {
        guard wss == nil else {
            context.cancelRequest(withError: AppExtensionError.serverAlreadyStarted)
            return
        }
        
        var isStale = false
        guard let item = context.inputItems.first as? NSExtensionItem,
              let serverPort = item.userInfo?["port"] as? Int,
              let frameworkDirectoryBookmarkData = item.userInfo?["frameworksDirectoryBookmark"] as? Data,
              let frameworkDirectoryURL = try? URL(resolvingBookmarkData: frameworkDirectoryBookmarkData, bookmarkDataIsStale: &isStale),
              frameworkDirectoryURL.startAccessingSecurityScopedResource()
        else {
            context.cancelRequest(withError: AppExtensionError.missingServerConfiguration)
            return
        }
        
        let wss = SwiftWS(port: serverPort, queue: queue)
        self.wss = wss
        
        let binaryExecutor = BinaryExecutor()
        
        wss.onConnection { ws, head in
            
            if self.executing {
                ws.close(code: 5000, reason: "server busy")
            }
            
            ws.onMessage { message in
                if self.executing {
                   binaryExecutor.listener.write(text: message.data)
                }else {
                    let jsonData = message.data.data(using: .utf8)!
                    guard let request: ExecutionRequestFrame = try? JSONDecoder().decode(ExecutionRequestFrame.self, from: jsonData) else {
                        ws.send("malformed message")
                        return
                    }
                    
                    self.executing = true
                    
                    var workingDirectoryUrl: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    
                    if let workingDirectoryBookmark = request.workingDirectoryBookmark,
                       let workingDirectoryURL = try? URL(resolvingBookmarkData: workingDirectoryBookmark, bookmarkDataIsStale: &isStale),
                       workingDirectoryUrl.startAccessingSecurityScopedResource() {
                        workingDirectoryUrl = workingDirectoryURL
                    }
                    
                    binaryExecutor.executeBinary(args: request.args, workingDirectory: workingDirectoryUrl, sharedFrameworksDirectory: frameworkDirectoryURL, ws: message.target)
                }
            }
            
            ws.onClose { _ in
                wss.close()
                exit(0)
            }
        }
    }
}
