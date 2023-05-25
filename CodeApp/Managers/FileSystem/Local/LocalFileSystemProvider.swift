//
//  LocalFileSystemProvider.swift
//  Code
//
//  Created by Ken Chung on 10/4/2022.
//

import Foundation

class LocalFileSystemProvider: FileSystemProvider {

    static var registeredScheme: String = "file"
    var gitServiceProvider: GitServiceProvider? = nil
    var searchServiceProvider: SearchServiceProvider? = nil
    var terminalServiceProvider: TerminalServiceProvider? = nil

    func write(
        at: URL, content: Data, atomically: Bool, overwrite: Bool,
        completionHandler: @escaping (Error?) -> Void
    ) {
        do {
            var options: Data.WritingOptions = []
            if atomically { options.update(with: .atomic) }
            if !overwrite { options.update(with: .withoutOverwriting) }
            try content.write(to: at, options: options)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    func contentsOfDirectory(at url: URL, completionHandler: @escaping ([URL]?, Error?) -> Void) {
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: nil)
            completionHandler(urls, nil)
        } catch {
            completionHandler(nil, error)
        }
    }

    func fileExists(at url: URL, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(FileManager.default.fileExists(atPath: url.path))
    }

    func createDirectory(
        at: URL, withIntermediateDirectories: Bool, completionHandler: @escaping (Error?) -> Void
    ) {
        do {
            try FileManager.default.createDirectory(
                at: at, withIntermediateDirectories: withIntermediateDirectories)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    func copyItem(at: URL, to: URL, completionHandler: @escaping (Error?) -> Void) {
        do {
            try FileManager.default.copyItem(at: at, to: to)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    func moveItem(at: URL, to: URL, completionHandler: @escaping (Error?) -> Void) {
        do {
            try FileManager.default.moveItem(at: at, to: to)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    func removeItem(at: URL, completionHandler: @escaping (Error?) -> Void) {
        do {
            try FileManager.default.removeItem(at: at)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    func contents(at: URL, completionHandler: @escaping (Data?, Error?) -> Void) {
        // Using a FileCoordinator allows downloading iCloud file using a completion handler pattern
        // Reference: https://developer.apple.com/forums/thread/681520
        var error: NSError?
        let fileCoordinator = NSFileCoordinator()

        fileCoordinator.coordinate(
            readingItemAt: at, options: .withoutChanges, error: &error
        ) { newURL in
            do {
                let data = try Data(contentsOf: newURL)
                completionHandler(data, nil)
            } catch {
                completionHandler(nil, error)
            }
            return
        }

        if let error {
            completionHandler(nil, error)
        }
    }

    func attributesOfItem(
        at: URL, completionHandler: @escaping ([FileAttributeKey: Any?]?, Error?) -> Void
    ) {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: at.path)
            completionHandler(attributes, nil)
        } catch {
            completionHandler(nil, error)
        }
    }
}
