//
//  FileSystemProvider.swift
//  Code
//
//  Created by Ken Chung on 10/4/2022.
//

import Foundation

protocol FileSystemProvider {
    static var registeredScheme: String { get }
    var gitServiceProvider: GitServiceProvider? { get }
    var searchServiceProvider: SearchServiceProvider? { get }
    var terminalServiceProvider: TerminalServiceProvider? { get }

    func contentsOfDirectory(at url: URL, completionHandler: @escaping ([URL]?, Error?) -> Void)
    func fileExists(at url: URL, completionHandler: @escaping (Bool) -> Void)
    func createDirectory(
        at: URL, withIntermediateDirectories: Bool, completionHandler: @escaping (Error?) -> Void)
    func copyItem(at: URL, to: URL, completionHandler: @escaping (Error?) -> Void)
    func moveItem(at: URL, to: URL, completionHandler: @escaping (Error?) -> Void)
    func removeItem(at: URL, completionHandler: @escaping (Error?) -> Void)
    func contents(at: URL, completionHandler: @escaping (Data?, Error?) -> Void)
    func write(
        at: URL, content: Data, atomically: Bool, overwrite: Bool,
        completionHandler: @escaping (Error?) -> Void)
    func attributesOfItem(
        at: URL, completionHandler: @escaping ([FileAttributeKey: Any?]?, Error?) -> Void)
}
