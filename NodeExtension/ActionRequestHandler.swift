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
    
    let stdinPipe = Pipe()
    
    let stdoutFileDescriptor = FileHandle.standardOutput.fileDescriptor
    let stderrFileDescriptor = FileHandle.standardError.fileDescriptor
    let stdinFileDescriptor = FileHandle.standardInput.fileDescriptor
    
    let coordinator = NSFileCoordinator(filePresenter: nil)
    
    func writeToSharedFile(data: Data){
        
        guard let string = String(data: data, encoding: String.Encoding.utf8) else { return }
        
        ExtensionCommunicationHelper.writeToStdout(data: string)
    }
    
    init(context: NSExtensionContext) {
        // Set up a read handler which fires when data is written to our inputPipe
        inputPipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            guard let strongSelf = self else { return }
            
            let data = fileHandle.availableData
            strongSelf.writeToSharedFile(data: data)
            // Write input back to stdout
            strongSelf.outputPipe.fileHandleForWriting.write(data)
        }
        
        inputErrorPipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            guard let strongSelf = self else { return }
            
            let data = fileHandle.availableData
            strongSelf.writeToSharedFile(data: data)
            // Write input back to stdout
            strongSelf.outputErrorPipe.fileHandleForWriting.write(data)
        }
        
        setupStdinNotificationObserver()
    }
    
    @objc private func onAppGroupStdinWrite(_ notification: Notification) {
        guard let content = notification.userInfo?["content"] as? String else {
            return
        }
        if let data = content.data(using: .utf8) {
            stdinPipe.fileHandleForWriting.write(data)
        }
    }
    
    private func setupStdinNotificationObserver() {
        let notificationName = "com.thebaselab.code.node.stdin" as CFString
        let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
        
        CFNotificationCenterAddObserver(
            notificationCenter, nil,
            {
                (
                    center: CFNotificationCenter?,
                    observer: UnsafeMutableRawPointer?,
                    name: CFNotificationName?,
                    object: UnsafeRawPointer?,
                    userInfo: CFDictionary?
                ) in

                let sharedURL = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: "group.com.thebaselab.code")!
                let stdoutURL = sharedURL.appendingPathComponent("stdin")

                guard let data = try? Data(contentsOf: stdoutURL),
                    let str = String(data: data, encoding: .utf8)
                else {
                    return
                }

                NotificationCenter.default.post(
                    name: Notification.Name("appgroup.stdin"), object: nil, userInfo: ["content": str])
            },
            notificationName,
            nil,
            CFNotificationSuspensionBehavior.deliverImmediately)
        
        NotificationCenter.default.addObserver(
            self, selector: #selector(onAppGroupStdinWrite), name: Notification.Name("appgroup.stdin"),
            object: nil)
    }
    
    /// Sets up the "tee" of piped output, intercepting stdout then passing it through.
    func openConsolePipe() {
        // Copy STDOUT file descriptor to outputPipe for writing strings back to STDOUT
        dup2(stdoutFileDescriptor, outputPipe.fileHandleForWriting.fileDescriptor)
        dup2(stderrFileDescriptor, outputErrorPipe.fileHandleForWriting.fileDescriptor)
        
        // Intercept STDOUT with inputPipe
        dup2(inputPipe.fileHandleForWriting.fileDescriptor, stdoutFileDescriptor)
        dup2(inputErrorPipe.fileHandleForWriting.fileDescriptor, stderrFileDescriptor)
        
        dup2(stdinPipe.fileHandleForReading.fileDescriptor, stdinFileDescriptor)
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

// Java attempts to re-run main() on first run:
// https://github.com/PojavLauncherTeam/openjdk-multiarch-jdk8u/blob/99f3f8bf37150677058ab00b76f9b17a1ab23a70/jdk/src/macosx/bin/java_md_macosx.c#L311
@_cdecl("main")
public func JavaEntrance(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    JavaLauncher.shared.launchJava(
        args: JavaLauncher.shared.lastArgs,
        frameworkDirectory: JavaLauncher.shared.lastFrameworkDir
    )
    return 0
}

class JavaLauncher {
    static let shared = JavaLauncher()
    
    var lastFrameworkDir: URL!
    var lastArgs: [String] = []
    var javaString: NSString = "java"
    var openJDKString: NSString = "openjdk"
    var versionStringFull: NSString = "1.8.0-internal"
    var versionString: NSString = "1.8.0"
    static let javaHome = "\(Bundle.main.resourcePath!)/java-8-openjdk"
    let defaultArgs = [
        "\(javaHome)/bin/java",
        "-XstartOnFirstThread",
        "-Djava.library.path=\(Bundle.main.bundlePath)/Frameworks",
        "-Djna.boot.library.path=\(Bundle.main.bundlePath)/Frameworks",
        "-Dorg.lwjgl.glfw.checkThread0=false",
        "-Dorg.lwjgl.system.allocator=system",
        "-Dlog4j2.formatMsgNoLookups=true",
        "-XX:+UnlockExperimentalVMOptions",
        "-XX:+DisablePrimordialThreadGuardPages",
        "-Djava.awt.headless=false",
        "-XX:-UseCompressedClassPointers",
        "-jre-restrict-search"
    ]
    
    typealias JLI_Launch = @convention(c) (
        Int32,
        UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?,
        Int32,
        UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?,
        Int32,
        UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?,
        UnsafeMutablePointer<CChar>?,
        UnsafeMutablePointer<CChar>?,
        UnsafeMutablePointer<CChar>?,
        UnsafeMutablePointer<CChar>?,
        Int32,
        Int32,
        Int32,
        Int32
    ) -> CInt
    
    func launchJava(args: [String], frameworkDirectory: URL){
        lastFrameworkDir = frameworkDirectory
        lastArgs = args
        
        let libjlipath = "\(frameworkDirectory.path)/libjli.framework/libjli"
        setenv("JAVA_HOME", JavaLauncher.javaHome, 1)
        setenv("INTERNAL_JLI_PATH", libjlipath, 1)
        setenv("HACK_IGNORE_START_ON_FIRST_THREAD", "1", 1)
        
//        For debug:
//        setenv("_JAVA_LAUNCHER_DEBUG", "1", 1)
        
        for lib in ["libffi.8", "libjvm", "libverify", "libjava", "libnet"]{
            let handle = dlopen("\(frameworkDirectory.path)/\(lib).framework/\(lib)", RTLD_GLOBAL)
            if (handle == nil) {
                if let error = dlerror(),
                    let str = String(validatingUTF8: error) {
                    print(str)
                }
                fatalError()
            }
        }
        
        let libjli = dlopen(libjlipath, RTLD_GLOBAL)
        if (libjli == nil){
            if let error = dlerror(),
                let str = String(validatingUTF8: error) {
                print(str)
            }
            return
        }
        
        let pJLI_Launch = dlsym(libjli, "JLI_Launch")
        let f = unsafeBitCast(pJLI_Launch, to: JLI_Launch.self)
        
        let realArgs = {
            if args.first == "java" {
                return (defaultArgs + args.dropFirst())
            }else if args.first == "javac" {
                return (
                    defaultArgs +
                    ["-cp",
                     "\(Bundle.main.resourcePath!)/tools.jar",
                     "com.sun.tools.javac.Main"
                    ]
                    + args.dropFirst()
                )
            }else {
                return defaultArgs
            }
        }()
        var cargs = realArgs.map{strdup($0) }
        
        let javaStringPtr = UnsafeMutablePointer<CChar>(mutating: javaString.utf8String)
        let openJDKStringPtr = UnsafeMutablePointer<CChar>(mutating: openJDKString.utf8String)
        let versionStringFullPtr = UnsafeMutablePointer<CChar>(mutating: versionStringFull.utf8String)
        let versionStringPtr = UnsafeMutablePointer<CChar>(mutating: versionString.utf8String)
        
        let result = f(
            Int32(cargs.count), &cargs,
            0, nil,
            0, nil,
            versionStringFullPtr,
            versionStringPtr,
            javaStringPtr,
            openJDKStringPtr,
            0,
            1,
            0,
            1
        )
        dlclose(libjli)
    }
    
}

class ActionRequestHandler: NSObject, NSExtensionRequestHandling {
    
    var extensionContext: NSExtensionContext?
    
    func beginRequest(with context: NSExtensionContext) {
        
        atexit {
            // Allow stdout to properly print before exit
            fflush(stdout)
            usleep(200000) // 0.2 seconds
        }
        
        setenv("npm_config_prefix", sharedURL.appendingPathComponent("lib").path, 1)
        setenv("npm_config_cache", FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.path, 1)
        setenv("npm_config_userconfig", FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(".npmrc").path, 1)
        setenv("COREPACK_HOME", sharedURL.appendingPathComponent("corepack").path, 1)
        setenv("TMPDIR", FileManager.default.temporaryDirectory.path, 1)
        setenv("YARN_CACHE_FOLDER", FileManager.default.temporaryDirectory.path, 1)
        setenv("HOME", sharedURL.path, 1)
        setenv("FORCE_COLOR", "3", 1)

        let injectionJSPath = Bundle.main.path(forResource: "injection", ofType: "js")!
        setenv("NODE_OPTIONS", "--jitless --require \"\(injectionJSPath)\"", 1)
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
        open("/dev/tty", 0);
        
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
        
        guard let frameworkDirdata = item.userInfo?["frameworksDirectoryBookmark"] as? Data else {
            return
        }
        let frameworkDirURL = try! URL(resolvingBookmarkData: frameworkDirdata, bookmarkDataIsStale: &isStale)
        _ = frameworkDirURL.startAccessingSecurityScopedResource()
        
        guard let args = item.userInfo?["args"] as? [String],
              let executable = args.first
        else {
            return
        }
        
        DispatchQueue.global(qos: .default).async {
            
            switch executable {
            case "java", "javac":
                JavaLauncher.shared.launchJava(args: args, frameworkDirectory: frameworkDirURL)
            case "node":
                NodeRunner.startEngine(withArguments: args)
            default:
                break
            }
            
            self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                output.closeConsolePipe()
                self.extensionContext = nil
                exit(0)
            }
            
        }
    }
}
