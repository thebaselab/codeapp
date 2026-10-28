//
//  Node.swift
//  extension
//
//  Created by Ken Chung on 02/07/2024.
//

import Foundation

let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.thebaselab.code")!

class NodeLauncher {
    static let shared = NodeLauncher()
    
    func launchNode(args: [String], environment: [String: String] = [:]) -> Int32 {
        setenv("npm_config_prefix", sharedURL.appendingPathComponent("lib").path, 1)
        setenv("npm_config_cache", FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.path, 1)
        setenv("npm_config_userconfig", FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(".npmrc").path, 1)
        setenv("COREPACK_HOME", sharedURL.appendingPathComponent("corepack").path, 1)
        setenv("TMPDIR", FileManager.default.temporaryDirectory.path, 1)
        setenv("YARN_CACHE_FOLDER", FileManager.default.temporaryDirectory.path, 1)
        setenv("HOME", sharedURL.path, 1)
        setenv("FORCE_COLOR", "3", 1)
        let injectionJSPath = Bundle.main.path(forResource: "injection", ofType: "js")!
        var nodeOptions = "--jitless --require \"\(injectionJSPath)\""
        for (key, value) in environment {
            // The injection script must always load, so user NODE_OPTIONS are appended instead of replacing it.
            if key == "NODE_OPTIONS" {
                nodeOptions += " " + value
            } else {
                setenv(key, value, 1)
            }
        }
        setenv("NODE_OPTIONS", nodeOptions, 1)
        
        return NodeRunner.startEngine(withArguments: args)
    }
}
