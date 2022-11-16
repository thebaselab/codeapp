//
//  Resources.swift
//  Code
//
//  Created by Ken Chung on 7/11/2022.
//

import Foundation

class Resources {
    static let appGroupSharedLibrary = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.com.thebaselab.code")

    static let clangLib = URL(fileURLWithPath: Bundle.main.resourcePath!).appendingPathComponent(
        "ClangLib")

    static let wasmHTML = URL(
        fileURLWithPath: Bundle.main.path(
            forResource: "wasm", ofType: "html", inDirectory: "ClangLib")!)

    static let themes = URL(fileURLWithPath: Bundle.main.resourcePath!).appendingPathComponent(
        "Themes")

    static let pythonLibrary = URL(fileURLWithPath: Bundle.main.resourcePath!)
        .appendingPathComponent(
            "Library")

    static let carcert = Bundle.main.url(forResource: "cacert", withExtension: "pem")!

    static let npm = Bundle.main.url(forResource: "npm", withExtension: "bundle")!
}
