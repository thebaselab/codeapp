//
//  ActionRequestHandler.swift
//  extension
//
//  Created by Ken Chung on 22/2/2021.
//

import UIKit
import MobileCoreServices

let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.thebaselab.code")!

class OutputListener {
    /// consumes the messages on STDOUT
    let inputPipe = Pipe()
    
    /// outputs messages back to STDOUT
    let outputPipe = Pipe()
    
    /// consumes the messages on STDERR
    let inputErrorPipe = Pipe()
    
    /// outputs messages back to STDOUT
    let outputErrorPipe = Pipe()
    
    /// Buffers strings written to stdout
    var contents = ""
    
    let stdoutFileDescriptor = FileHandle.standardOutput.fileDescriptor
    let stderrFileDescriptor = FileHandle.standardError.fileDescriptor
    
    let coordinator = NSFileCoordinator(filePresenter: nil)
    
    init(context: NSExtensionContext) {
        // Set up a read handler which fires when data is written to our inputPipe
        inputPipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            guard let strongSelf = self else { return }
            
            let data = fileHandle.availableData
            if let string = String(data: data, encoding: String.Encoding.utf8) {
                var error: NSError?
                strongSelf.coordinator.coordinate(writingItemAt: sharedURL.appendingPathComponent("stdout"), options: .forReplacing, error: &error, byAccessor: { url in
                    try? string.write(to: url, atomically: true, encoding: .utf8)
                    
                    let notificationName = CFNotificationName("com.thebaselab.code.node.stdout" as CFString)
                    let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
                    CFNotificationCenterPostNotification(notificationCenter, notificationName, nil, nil, false)
                })
            }
            // Write input back to stdout
            strongSelf.outputPipe.fileHandleForWriting.write(data)
        }
        
        inputErrorPipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            guard let strongSelf = self else { return }
            
            let data = fileHandle.availableData
            if let string = String(data: data, encoding: String.Encoding.utf8) {
                let item = NSExtensionItem()
                item.userInfo = ["result": string]
                context.completeRequest(returningItems: [item], completionHandler: nil)
                strongSelf.contents += string
            }
            
            // Write input back to stdout
            strongSelf.outputErrorPipe.fileHandleForWriting.write(data)
        }
    }
    
    /// Sets up the "tee" of piped output, intercepting stdout then passing it through.
    func openConsolePipe() {
        // Copy STDOUT file descriptor to outputPipe for writing strings back to STDOUT
        dup2(stdoutFileDescriptor, outputPipe.fileHandleForWriting.fileDescriptor)
        dup2(stderrFileDescriptor, outputErrorPipe.fileHandleForWriting.fileDescriptor)
        
        // Intercept STDOUT with inputPipe
        dup2(inputPipe.fileHandleForWriting.fileDescriptor, stdoutFileDescriptor)
        dup2(inputErrorPipe.fileHandleForWriting.fileDescriptor, stderrFileDescriptor)
    }
    
    /// Tears down the "tee" of piped output.
    func closeConsolePipe() {
        // Restore stdout
        freopen("/dev/stdout", "a", stdout)
        freopen("/dev/stderr", "a", stdout)
        
        [inputPipe.fileHandleForReading, outputPipe.fileHandleForWriting].forEach { file in
            file.closeFile()
        }
    }
    
}

class ActionRequestHandler: NSObject, NSExtensionRequestHandling {
    
    var extensionContext: NSExtensionContext?
    
    func beginRequest(with context: NSExtensionContext) {
        setenv("npm_config_prefix", sharedURL.appendingPathComponent("lib").path, 1)
        setenv("npm_config_cache", FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.path, 1)
        setenv("npm_config_userconfig", FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(".npmrc").path, 1)
        setenv("COREPACK_HOME", sharedURL.appendingPathComponent("corepack").path, 1)
        setenv("TMPDIR", FileManager.default.temporaryDirectory.path, 1)
        setenv("YARN_CACHE_FOLDER", FileManager.default.temporaryDirectory.path, 1)
        setenv("HOME", sharedURL.path, 1)
        // Do not call super in an Action extension with no user interface
        self.extensionContext = context
        
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
        
        let output = OutputListener(context: context)
        output.openConsolePipe()
        
        guard let item = context.inputItems.first as? NSExtensionItem else {
            self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        
        var isStale = false
        
        guard let data = item.userInfo?["workingDirectoryBookmark"] as? Data else {
            return
        }
        
        let url = try! URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
        _ = url.startAccessingSecurityScopedResource()
        FileManager.default.changeCurrentDirectoryPath(url.path)
        
        guard let args = item.userInfo?["args"] as? [String] else {
            return
        }
        
        DispatchQueue.global(qos: .default).async {
            NodeRunner.startEngine(withArguments: args)
            
            self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                output.closeConsolePipe()
                self.extensionContext = nil
                exit(0)
            }
            
        }
    }
}
