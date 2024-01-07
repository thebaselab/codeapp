//
//  CodeApp.swift
//  Code App
//
//  Created by Ken Chung on 17/11/2020.
//

import SwiftGit2
import SwiftUI
import UIKit
import WebKit
import ios_system

@main
struct CodeApp: App {
    @StateObject var themeManager = ThemeManager()

    func versionNumberIncreased() -> Bool {
        if let lastReadVersion = UserDefaults.standard.string(forKey: "changelog.lastread") {
            let currentVersion =
                Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
            if lastReadVersion != currentVersion {
                return true
            }
        } else {
            return true
        }
        print("Version Number not increased")
        return false
    }

    // From a-shell: https://github.com/holzschu/a-shell/blob/9eb0f4c94a9bdc3b24460c3ed82a156f5b33bb2f/a-Shell/AppDelegate.swift

    func executeCommandAndWait(command: String) {
        let pid = ios_fork()
        _ = ios_system(command)
        fflush(thread_stdout)
        ios_waitpid(pid)
        ios_releaseThreadId(pid)
    }

    func needToUpdateCFiles() -> Bool {
        // Check that the C SDK files are present:
        let libraryURL = try! FileManager().url(
            for: .libraryDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true)
        // NSLog("Library file exists: \(FileManager().fileExists(atPath: libraryURL.appendingPathComponent("usr/lib/wasm32-wasi/libwasi-emulated-mman.a").path))")
        // NSLog("Header file exists: \(FileManager().fileExists(atPath: libraryURL.appendingPathComponent("usr/include/stdio.h").path))")
        return
            !(FileManager().fileExists(
                atPath: libraryURL.appendingPathComponent(
                    "usr/lib/wasm32-wasi/libwasi-emulated-mman.a"
                ).path)
            && FileManager().fileExists(
                atPath: libraryURL.appendingPathComponent("usr/include/stdio.h").path))
    }

    func createCSDK() {
        let installQueue = DispatchQueue(label: "installFiles", qos: .userInteractive)

        // This operation copies the C SDK from $APPDIR to $HOME/Library and creates the *.a libraries
        // (we can't ship with .a libraries because of the AppStore rules, but we can ship with *.o
        // object files, provided they are in WASM format.
        installQueue.async {
            // Use a queue so it does not take time at startup:
            NSLog("Starting creating C SDK")
            let libraryURL = try! FileManager().url(
                for: .libraryDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true)
            // usr/lib/wasm32-wasi
            var localURL = libraryURL.appendingPathComponent("usr/lib/wasm32-wasi")
            do {
                if FileManager().fileExists(atPath: localURL.path) && !localURL.isDirectory {
                    try FileManager().removeItem(at: localURL)
                }
                if !FileManager().fileExists(atPath: localURL.path) {
                    try FileManager().createDirectory(
                        atPath: localURL.path, withIntermediateDirectories: true)
                }
            } catch {
                NSLog("Error in creating C SDK directory \(localURL): \(error)")
                return
            }
            // usr/lib/clang/14.0.0/lib/wasi/
            localURL = libraryURL.appendingPathComponent("usr/lib/clang/14.0.0/lib/wasi/")
            do {
                if FileManager().fileExists(atPath: localURL.path) && !localURL.isDirectory {
                    try FileManager().removeItem(at: localURL)
                }
                if !FileManager().fileExists(atPath: localURL.path) {
                    try FileManager().createDirectory(
                        atPath: localURL.path, withIntermediateDirectories: true)
                }
            } catch {
                NSLog("Error in creating C SDK directory \(localURL): \(error)")
                return
            }
            let linkedCDirectories = [
                "usr/include",
                "usr/share",
                "usr/lib/wasm32-wasi/crt1.o",
                "usr/lib/wasm32-wasi/libc.imports",
                "usr/lib/clang/14.0.0/include",
            ]

            for linkedObject in linkedCDirectories {
                let bundleFile = Resources.clangLib.appendingPathComponent(linkedObject)
                if !FileManager().fileExists(atPath: bundleFile.path) {
                    NSLog("createCSDK: requested file \(bundleFile.path) does not exist")
                    continue
                }
                // Symbolic links are both faster to create and use less disk space.
                // We just have to make sure the destination exists
                let homeFile = libraryURL.appendingPathComponent(linkedObject)
                do {
                    let firstFileAttribute = try FileManager().attributesOfItem(
                        atPath: homeFile.path)
                    if firstFileAttribute[FileAttributeKey.type] as? String
                        == FileAttributeType.typeSymbolicLink.rawValue
                    {
                        // It's a symbolic link, does the destination exist?
                        let destination = try! FileManager().destinationOfSymbolicLink(
                            atPath: homeFile.path)
                        if !FileManager().fileExists(atPath: destination) {
                            try! FileManager().removeItem(at: homeFile)
                            try! FileManager().createSymbolicLink(
                                at: homeFile, withDestinationURL: bundleFile)
                        }
                    } else {
                        // Not a symbolic link, replace:
                        try! FileManager().removeItem(at: homeFile)
                        try! FileManager().createSymbolicLink(
                            at: homeFile, withDestinationURL: bundleFile)
                    }
                } catch {
                    // The file does not exist, and maybe the directory doesn't either:
                    let localDirectory = homeFile.deletingLastPathComponent()
                    if !FileManager().fileExists(atPath: localDirectory.path) {
                        try! FileManager().createDirectory(
                            atPath: localDirectory.path, withIntermediateDirectories: true)
                    }
                    do {
                        try FileManager().createSymbolicLink(
                            at: homeFile, withDestinationURL: bundleFile)
                    } catch {
                        NSLog("Can't create file: \(homeFile.path): \(error)")
                    }
                }
            }
            // Now create the empty libraries:
            let emptyLibraries = [
                // m rt pthread crypt util xnet resolv dl
                "lib/wasm32-wasi/libcrypt.a",
                "lib/wasm32-wasi/libdl.a",
                "lib/wasm32-wasi/libm.a",
                "lib/wasm32-wasi/libpthread.a",
                "lib/wasm32-wasi/libresolv.a",
                "lib/wasm32-wasi/librt.a",
                "lib/wasm32-wasi/libutil.a",
                "lib/wasm32-wasi/libxnet.a",
            ]
            ios_switchSession("wasiSDKLibrariesCreation")
            for library in emptyLibraries {
                let libraryFileURL = libraryURL.appendingPathComponent("/usr/" + library)
                if !FileManager().fileExists(atPath: libraryFileURL.path) {
                    executeCommandAndWait(command: "ar crs " + libraryURL.path + "/usr/" + library)
                }
            }
            // One of the libraries is in a different folder:
            let libraryFileURL = libraryURL.appendingPathComponent(
                "/usr/lib/clang/14.0.0/lib/wasi/libclang_rt.builtins-wasm32.a")
            if FileManager().fileExists(atPath: libraryFileURL.path) {
                try! FileManager().removeItem(at: libraryFileURL)
            }
            let rootDir = Bundle.main.resourcePath! + "/ClangLib"
            executeCommandAndWait(
                command: "ar cq " + libraryFileURL.path + " " + rootDir
                    + "/usr/src/libclang_rt.builtins-wasm32/*")
            executeCommandAndWait(command: "ranlib " + libraryFileURL.path)
            let libraries = [
                "libc", "libc++", "libc++abi", "libc-printscan-long-double",
                "libc-printscan-no-floating-point", "libwasi-emulated-mman",
                "libwasi-emulated-signal", "libwasi-emulated-process-clocks",
            ]
            for library in libraries {
                let libraryFileURL = libraryURL.appendingPathComponent(
                    "usr/lib/wasm32-wasi/" + library + ".a")
                if FileManager().fileExists(atPath: libraryFileURL.path) {
                    do { try FileManager().removeItem(at: libraryFileURL) } catch {
                        NSLog("Can't remove \(libraryFileURL.path)")
                    }
                }
                executeCommandAndWait(
                    command: "ar cq " + libraryFileURL.path + " " + rootDir + "/usr/src/" + library
                        + "/*")
                executeCommandAndWait(command: "ranlib " + libraryFileURL.path)
            }
            NSLog("Finished creating C SDK")  // Approx 2 seconds
        }
    }

    init() {
        UITableView.appearance().backgroundColor = UIColor.clear
        UITableViewCell.appearance().backgroundColor = UIColor.clear
        UITableView.appearance().separatorStyle = .none
        UITextView.appearance().backgroundColor = .clear

        replaceCommand("node", "node", true)
        replaceCommand("npm", "npm", true)
        replaceCommand("npx", "npx", true)
        replaceCommand("wasm", "wasm", true)
        replaceCommand("java", "java", true)
        replaceCommand("javac", "javac", true)

        refreshNodeCommands()

        let libraryURL = try! FileManager().url(
            for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

        // Main Python install: $APPDIR/Library/lib/python3.x
        let bundleUrl = Resources.pythonLibrary
        setenv("PYTHONHOME", bundleUrl.path.toCString(), 1)
        // Compiled files: ~/Library/__pycache__
        setenv(
            "PYTHONPYCACHEPREFIX",
            (libraryURL.appendingPathComponent("__pycache__")).path.toCString(), 1)
        setenv("PYTHONUSERBASE", libraryURL.path.toCString(), 1)
        setenv("SSL_CERT_FILE", Resources.carcert.path.toCString(), 1)

        // Help aiohttp install itself:
        setenv("YARL_NO_EXTENSIONS", "1", 1)
        setenv("MULTIDICT_NO_EXTENSIONS", "1", 1)

        // clang options:
        setenv("SYSROOT", libraryURL.path + "/usr", 1)
        setenv(
            "CCC_OVERRIDE_OPTIONS",
            "#^--target=wasm32-wasi +-fno-exceptions +-lc-printscan-long-double", 1)
        setenv("MAKESYSPATH", Bundle.main.resourcePath! + "ClangLib/usr/share/mk", 1)

        // PHP config
        setenv("PHPRC", bundleUrl.path.toCString(), 1)
        // Git config
        //        setenv("HOME", libraryURL.path, 1)
        setenv("GIT_EXEC_PATH", bundleUrl.appendingPathComponent("bin").path.toCString(), 1)
        // Magic file
        //        setenv("MAGIC", Bundle.main.resourcePath! + "/usr/share/magic.mgc", 1)
        joinMainThread = false
        numPythonInterpreters = 2

        let notificationName = "com.thebaselab.code.node.stdout" as CFString
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
                let stdoutURL = sharedURL.appendingPathComponent("stdout")

                guard let data = try? Data(contentsOf: stdoutURL),
                    let str = String(data: data, encoding: .utf8)
                else {
                    return
                }

                let nc = NotificationCenter.default
                nc.post(
                    name: Notification.Name("node.stdout"), object: nil, userInfo: ["content": str])

            },
            notificationName,
            nil,
            CFNotificationSuspensionBehavior.deliverImmediately)

        // Disable mini map and line number for iPhones
        if UIScreen.main.traitCollection.horizontalSizeClass == .compact {
            if UserDefaults.standard.object(forKey: "editorLineNumberEnabled") == nil {
                UserDefaults.standard.setValue(false, forKey: "editorLineNumberEnabled")
                UserDefaults.standard.setValue(false, forKey: "editorMiniMapEnabled")
            }
            if UserDefaults.standard.object(forKey: "compilerShowPath") == nil {
                UserDefaults.standard.setValue(false, forKey: "compilerShowPath")
            }
        }

        if versionNumberIncreased() || needToUpdateCFiles() {
            createCSDK()
        }

        DispatchQueue.main.async {
            wasmWebView.loadFileURL(
                Resources.wasmHTML,
                allowingReadAccessTo: Resources.wasmHTML)
        }
        initializeEnvironment()
        Repository.initialize_libgit2()
    }

    var window: UIWindow? {
        guard let scene = UIApplication.shared.connectedScenes.first,
            let windowSceneDelegate = scene.delegate as? UIWindowSceneDelegate,
            let window = windowSceneDelegate.window
        else {
            return nil
        }
        return window
    }

    var body: some Scene {
        WindowGroup {
            MainScene()
                .ignoresSafeArea(.container, edges: .bottom)
                .preferredColorScheme(themeManager.colorSchemePreference)
                .environmentObject(themeManager)
        }
    }
}

func refreshNodeCommands() {
    let nodeBinPath = Resources.appGroupSharedLibrary?.appendingPathComponent("lib/bin").path

    if let nodeBinPath = nodeBinPath,
        let paths = try? FileManager.default.contentsOfDirectory(atPath: nodeBinPath)
    {
        paths.forEach { path in
            let cmd = path.replacingOccurrences(of: nodeBinPath, with: "")
            replaceCommand(cmd, "nodeg", true)
        }
    }
}
