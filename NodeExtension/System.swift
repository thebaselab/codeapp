//
//  System.swift
//  extension
//
//  Created by Ken Chung on 08/08/2024.
//

import ios_system

class Resources {
    // https://stackoverflow.com/questions/26189060/get-the-main-app-bundle-from-within-extension
    static func getMainAppBundle() -> Bundle {
        var bundle = Bundle.main
        if bundle.bundleURL.pathExtension == "appex" {
            // Peel off two directory levels - MY_APP.app/PlugIns/MY_APP_EXTENSION.appex
            let url = bundle.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            if let otherBundle = Bundle(url: url) {
                bundle = otherBundle
            }
        }
        return bundle
    }

    static let pythonLibrary = URL(fileURLWithPath: Resources.getMainAppBundle().resourcePath!)
        .appendingPathComponent(
            "Library")
    
    static let carcert = Resources.getMainAppBundle().url(forResource: "cacert", withExtension: "pem")!
    
    static let pythonLSP = "\(Resources.getMainAppBundle().resourcePath!)/python-lsp"
    
    static let javaLSP = "\(Bundle.main.resourcePath!)/java-lsp/fat-jar.jar"
}



class SystemCommandLauncher {
    static let shared = SystemCommandLauncher()
    
    func launchSystemCommand(args: [String]){
        ios_setStreams(stdin, stdout, stderr)
        
        ios_setDirectoryURL(URL(filePath: FileManager.default.currentDirectoryPath))
        
        joinMainThread = false
        numPythonInterpreters = 2
        
        let libraryURL = try! FileManager().url(
            for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let bundleUrl = Resources.pythonLibrary
        setenv("PYTHONHOME", bundleUrl.path.toCString(), 1)
        setenv(
            "PYTHONPYCACHEPREFIX",
            (libraryURL.appendingPathComponent("__pycache__")).path.toCString(), 1)
        setenv("PYTHONUSERBASE", libraryURL.path.toCString(), 1)
        setenv("SSL_CERT_FILE", Resources.carcert.path.toCString(), 1)
        setenv("YARL_NO_EXTENSIONS", "1", 1)
        setenv("MULTIDICT_NO_EXTENSIONS", "1", 1)
        setenv("SYSROOT", libraryURL.path + "/usr", 1)
        setenv("PYTHONPATH", "\(Resources.pythonLSP)/site-packages", 1)
        if let home = getenv("PATH") {
            setenv("PATH", String(utf8String: home)! + ":\(Resources.pythonLSP)/bin", 1)
        }
        
        
        let pid = ios_fork()
        ios_system(args.joined(separator: " "))
        ios_waitpid(pid)
        ios_releaseThreadId(pid)
        
        fflush(stdout)
        fflush(stdout)
    }
}
