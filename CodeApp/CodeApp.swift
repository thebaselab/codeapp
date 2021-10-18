//
//  CodeApp.swift
//  Code App
//
//  Created by Ken Chung on 17/11/2020.
//

import SwiftUI
import UIKit
import ios_system
import WebKit

@main
struct CodeApp: App {
    
    var window: UIWindow? {
        guard let scene = UIApplication.shared.connectedScenes.first,
              let windowSceneDelegate = scene.delegate as? UIWindowSceneDelegate,
              let window = windowSceneDelegate.window else {
            return nil
        }
        return window
    }
    
    @State private var App = MainApp()
    
    @AppStorage("editorLightTheme") var selectedLightTheme: String = "Light+"
    @AppStorage("editorDarkTheme") var selectedTheme: String = "Dark+"
    
    func loadBuiltInThemes(){
        
        globalThemes.removeAll()
        
        let bundleUrl = URL(fileURLWithPath: Bundle.main.resourcePath!).appendingPathComponent("Library")
        
        let themesURL = bundleUrl.appendingPathComponent("editor/themes")
        let themesPaths = try! FileManager.default.contentsOfDirectory(at: themesURL, includingPropertiesForKeys: nil)
        
        for path in themesPaths {
            if let data = try? Data(contentsOf: path),
               let jsonArray = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? Dictionary<String, Any>,
               let name = jsonArray["name"] as? String,
               let type = jsonArray["type"] as? String,
               let colorArray = jsonArray["colors"] as? Dictionary<String, String>
            {
                if selectedTheme == name && type == "dark"{
                    globalDarkTheme = jsonArray
                }
                if selectedLightTheme == name && type != "dark"{
                    globalLightTheme = jsonArray
                }
                
                let previewColors = ["editor.background", "activityBar.background", "statusBar.background", "sideBar.background"]
                
                let preview = previewColors.map{Color.init(hexString: colorArray[$0] ?? $0)}
                
                let result = (preview[0], preview[1], preview[2], preview[3])
                
                globalThemes.append(theme(name: name, url: path, isDark: type == "dark", preview: result))
            }else{
                print("READ ERROR: \(path)")
            }
        }
    }
    
    func versionNumberIncreased() -> Bool {
        if let lastReadVersion = UserDefaults.standard.string(forKey: "changelog.lastread"){
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
            if lastReadVersion != currentVersion{
                return true
            }
        }else{
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
            let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                    in: .userDomainMask,
                                                    appropriateFor: nil,
                                                    create: true)
            // NSLog("Library file exists: \(FileManager().fileExists(atPath: libraryURL.appendingPathComponent("usr/lib/wasm32-wasi/libwasi-emulated-mman.a").path))")
            // NSLog("Header file exists: \(FileManager().fileExists(atPath: libraryURL.appendingPathComponent("usr/include/stdio.h").path))")
            return !(FileManager().fileExists(atPath: libraryURL.appendingPathComponent("usr/lib/wasm32-wasi/libwasi-emulated-mman.a").path)
             && FileManager().fileExists(atPath: libraryURL.appendingPathComponent("usr/include/stdio.h").path))
        }
    
    func createCSDK() {
        let installQueue = DispatchQueue(label: "installFiles", qos: .userInteractive)
        
        // This operation copies the C SDK from $APPDIR to $HOME/Library and creates the *.a libraries
        // (we can't ship with .a libraries because of the AppStore rules, but we can ship with *.o
        // object files, provided they are in WASM format.
        installQueue.async{
            // Use a queue so it does not take time at startup:
            NSLog("Starting creating C SDK")
            let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                    in: .userDomainMask,
                                                    appropriateFor: nil,
                                                    create: true)
            // usr/lib/wasm32-wasi
            var localURL = libraryURL.appendingPathComponent("usr/lib/wasm32-wasi") // $HOME/Library/usr/lib/wasm32-wasi
            do {
                if (FileManager().fileExists(atPath: localURL.path) && !localURL.isDirectory) {
                    try FileManager().removeItem(at: localURL)
                }
                if (!FileManager().fileExists(atPath: localURL.path)) {
                    try FileManager().createDirectory(atPath: localURL.path, withIntermediateDirectories: true)
                }
            } catch {
                NSLog("Error in creating C SDK directory \(localURL): \(error)")
                return
            }
            // usr/lib/clang/13.0.0/lib/wasi/
            localURL = libraryURL.appendingPathComponent("usr/lib/clang/13.0.0/lib/wasi/") // $HOME/Library/usr/lib/clang/13.0.0/lib/wasi/
            do {
                if (FileManager().fileExists(atPath: localURL.path) && !localURL.isDirectory) {
                    try FileManager().removeItem(at: localURL)
                }
                if (!FileManager().fileExists(atPath: localURL.path)) {
                    try FileManager().createDirectory(atPath: localURL.path, withIntermediateDirectories: true)
                }
            } catch {
                NSLog("Error in creating C SDK directory \(localURL): \(error)")
                return
            }
            let linkedCDirectories = ["usr/include",
                                      "usr/share",
                                      "usr/lib/wasm32-wasi/crt1.o",
                                      "usr/lib/wasm32-wasi/libc.imports",
                                      "usr/lib/clang/13.0.0/include",
            ]
            let bundleUrl = URL(fileURLWithPath: Bundle.main.resourcePath!).appendingPathComponent("ClangLib")
            
            for linkedObject in linkedCDirectories {
                let bundleFile = bundleUrl.appendingPathComponent(linkedObject)
                if (!FileManager().fileExists(atPath: bundleFile.path)) {
                    NSLog("createCSDK: requested file \(bundleFile.path) does not exist")
                    continue
                }
                // Symbolic links are both faster to create and use less disk space.
                // We just have to make sure the destination exists
                let homeFile = libraryURL.appendingPathComponent(linkedObject)
                do {
                    let firstFileAttribute = try FileManager().attributesOfItem(atPath: homeFile.path)
                    if (firstFileAttribute[FileAttributeKey.type] as? String == FileAttributeType.typeSymbolicLink.rawValue) {
                        // It's a symbolic link, does the destination exist?
                        let destination = try! FileManager().destinationOfSymbolicLink(atPath: homeFile.path)
                        if (!FileManager().fileExists(atPath: destination)) {
                            try! FileManager().removeItem(at: homeFile)
                            try! FileManager().createSymbolicLink(at: homeFile, withDestinationURL: bundleFile)
                        }
                    } else {
                        // Not a symbolic link, replace:
                        try! FileManager().removeItem(at: homeFile)
                        try! FileManager().createSymbolicLink(at: homeFile, withDestinationURL: bundleFile)
                    }
                }
                catch {
                    // The file does not exist, and maybe the directory doesn't either:
                    let localDirectory = homeFile.deletingLastPathComponent()
                    if (!FileManager().fileExists(atPath: localDirectory.path)) {
                        try! FileManager().createDirectory(atPath: localDirectory.path, withIntermediateDirectories: true)
                    }
                    do {
                        try FileManager().createSymbolicLink(at: homeFile, withDestinationURL: bundleFile)
                    }
                    catch {
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
                "lib/wasm32-wasi/libxnet.a"]
            ios_switchSession("wasiSDKLibrariesCreation")
            for library in emptyLibraries {
                let libraryFileURL = libraryURL.appendingPathComponent("/usr/" + library)
                if (!FileManager().fileExists(atPath: libraryFileURL.path)) {
                    executeCommandAndWait(command: "ar crs " + libraryURL.path + "/usr/" + library)
                }
            }
            // One of the libraries is in a different folder:
            let libraryFileURL = libraryURL.appendingPathComponent("/usr/lib/clang/13.0.0/lib/wasi/libclang_rt.builtins-wasm32.a")
            if (FileManager().fileExists(atPath: libraryFileURL.path)) {
                try! FileManager().removeItem(at: libraryFileURL)
            }
            let rootDir = Bundle.main.resourcePath! + "/ClangLib"
            executeCommandAndWait(command: "ar cq " + libraryFileURL.path + " " + rootDir + "/usr/src/libclang_rt.builtins-wasm32/*")
            executeCommandAndWait(command: "ranlib " + libraryFileURL.path)
            let libraries = ["libc", "libc++", "libc++abi", "libc-printscan-long-double", "libc-printscan-no-floating-point", "libwasi-emulated-mman", "libwasi-emulated-signal", "libwasi-emulated-process-clocks"]
            for library in libraries {
                let libraryFileURL = libraryURL.appendingPathComponent("usr/lib/wasm32-wasi/" + library + ".a")
                if (FileManager().fileExists(atPath: libraryFileURL.path)) {
                    do { try FileManager().removeItem(at: libraryFileURL) }
                    catch { NSLog("Can't remove \(libraryFileURL.path)")}
                }
                executeCommandAndWait(command: "ar cq " + libraryFileURL.path + " " + rootDir + "/usr/src/" + library + "/*")
                executeCommandAndWait(command: "ranlib " + libraryFileURL.path)
            }
            NSLog("Finished creating C SDK") // Approx 2 seconds
        }
    }
    
    init(){
        UITableView.appearance().backgroundColor = UIColor.clear
        UITableViewCell.appearance().backgroundColor = UIColor.clear
        UITableView.appearance().separatorStyle = .none
        UITextView.appearance().backgroundColor = .clear
        
        replaceCommand("node", "node", true)
        replaceCommand("npm", "npm", true)
        replaceCommand("npx", "npx", true)
        replaceCommand("wasm", "wasm", true)
        
        refreshNodeCommands()
        
        let libraryURL = try! FileManager().url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        
        let pemUrl = Bundle.main.url(forResource: "cacert", withExtension: "pem")!
        
        // Main Python install: $APPDIR/Library/lib/python3.x
        let bundleUrl = URL(fileURLWithPath: Bundle.main.resourcePath!).appendingPathComponent("Library")
        setenv("PYTHONHOME", bundleUrl.path.toCString(), 1)
        // Compiled files: ~/Library/__pycache__
        setenv("PYTHONPYCACHEPREFIX", (libraryURL.appendingPathComponent("__pycache__")).path.toCString(), 1)
        setenv("PYTHONUSERBASE", libraryURL.path.toCString(), 1)
        
//        setenv("REQUESTS_CA_BUNDLE", pemUrl.path.toCString(), 1)
        setenv("SSL_CERT_FILE", pemUrl.path.toCString(), 1)
        
        // Help aiohttp install itself:
        setenv("YARL_NO_EXTENSIONS", "1", 1)
        setenv("MULTIDICT_NO_EXTENSIONS", "1", 1)
        
        // clang options:
        setenv("SYSROOT", libraryURL.path + "/usr", 1) // sysroot for clang compiler
        setenv("CCC_OVERRIDE_OPTIONS", "#^--target=wasm32-wasi +-fno-exceptions", 1) // silently add "--target=wasm32-wasi" at the beginning of arguments
        setenv("MAKESYSPATH", Bundle.main.resourcePath! +  "ClangLib/usr/share/mk" , 1)
        
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
        
        CFNotificationCenterAddObserver(notificationCenter, nil,
                                        { (
                                            center: CFNotificationCenter?,
                                            observer: UnsafeMutableRawPointer?,
                                            name: CFNotificationName?,
                                            object: UnsafeRawPointer?,
                                            userInfo: CFDictionary?
                                        ) in
                                            
                                            let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.thebaselab.code")!
                                            let stdoutURL = sharedURL.appendingPathComponent("stdout")
                                            
                                            guard let data = try? Data(contentsOf: stdoutURL), let str = String(data: data, encoding: .utf8) else {
                                                return
                                            }
                                            
                                            let nc = NotificationCenter.default
                                            nc.post(name: Notification.Name("node.stdout"), object: nil, userInfo: ["content": str])
                                            
                                        },
                                        notificationName,
                                        nil,
                                        CFNotificationSuspensionBehavior.deliverImmediately)
        
        loadBuiltInThemes()
        
        // Disable mini map and line number for iPhones
        if UIScreen.main.traitCollection.horizontalSizeClass == .compact{
            if UserDefaults.standard.object(forKey: "editorLineNumberEnabled") == nil {
                UserDefaults.standard.setValue(false, forKey: "editorLineNumberEnabled")
                UserDefaults.standard.setValue(false, forKey: "editorMiniMapEnabled")
            }
            if UserDefaults.standard.object(forKey: "compilerShowPath") == nil {
                UserDefaults.standard.setValue(false, forKey: "compilerShowPath")
            }
        }
        
        if (versionNumberIncreased() || needToUpdateCFiles()) {
            createCSDK()
        }
        
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences.setValue(true as Bool, forKey: "allowFileAccessFromFileURLs")
        
        let wasmFilePath = Bundle.main.path(forResource: "wasm", ofType: "html", inDirectory: "ClangLib")
//        let wv = WKWebView(frame: .zero, configuration: config)
        wasmWebView.isOpaque = false
        wasmWebView.loadFileURL(URL(fileURLWithPath: wasmFilePath!), allowingReadAccessTo: URL(fileURLWithPath: wasmFilePath!))
        wasmWebView.configuration.userContentController = WKUserContentController()
        
        let delegate = wasmWebViewDelegate()
        wasmWebView.configuration.userContentController.add(delegate, name: "aShell")
        wasmWebView.navigationDelegate = delegate
        wasmWebView.uiDelegate = delegate
        wasmWebView.isAccessibilityElement = false
        
    }
    
    var body: some Scene {
        WindowGroup {
            mainView()
                .environmentObject(App)
                .ignoresSafeArea(.container, edges: .bottom)
                .onAppear{
                    if UserDefaults.standard.integer(forKey: "preferredColorScheme") == 1{
                        window?.overrideUserInterfaceStyle = .dark
                    }else if UserDefaults.standard.integer(forKey: "preferredColorScheme") == 2{
                        window?.overrideUserInterfaceStyle = .light
                    }
                }
                .onOpenURL {url in
                    _ = url.startAccessingSecurityScopedResource()
                    try? FileManager.default.startDownloadingUbiquitousItem(at: url)
                    if isEditorInited{
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            App.openEditor(urlString: url.standardizedFileURL.absoluteString, type: .file)
                        }
                    }else{
                        App.urlQueue.append(url)
                    }
                    print("Received URL: \(url)")
                }
        }
    }
}

struct theme {
    let id = UUID()
    let name: String
    let url: URL
    let isDark: Bool
    
    // editor.background, activitybar.background, statusbar_background, sidebar_background
    let preview: (Color, Color, Color, Color)
}

var globalThemes: [theme] = []
var globalDarkTheme: [String: Any]? = nil
var globalLightTheme: [String: Any]? = nil

func sharedURL() -> URL{
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.thebaselab.code")!
}

func refreshNodeCommands() {
    let nodeBinPath = sharedURL().appendingPathComponent("lib/bin").path
    
    if let paths = try? FileManager.default.contentsOfDirectory(atPath: nodeBinPath) {
        for i in paths {
            let cmd = i.replacingOccurrences(of: nodeBinPath, with: "")
            replaceCommand(cmd, "nodeg", true)
        }
    }
}
