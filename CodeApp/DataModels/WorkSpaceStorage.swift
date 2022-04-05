//
//  WorkSpaceStorage.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import FilesProvider
import Foundation
import SwiftUI

enum FSError: Error {
    case notImplemented
    case schemeNotRegistered
    case invalidHost
    case unsupportedEncoding
}

protocol FileSystemProvider {
    static var registeredScheme: String { get }

    func contentsOfDirectory(at url: URL, completionHandler: @escaping ([URL]?, Error?) -> Void)
    func fileExists(at url: URL, completionHandler: @escaping (Bool) -> Void)
    func createDirectory(
        at: URL, withIntermediateDirectories: Bool, completionHandler: @escaping (Error?) -> Void)
    func copyItem(at: URL, to: URL, completionHandler: @escaping (Error?) -> Void)
    func removeItem(at: URL, completionHandler: @escaping (Error?) -> Void)
    func contents(at: URL, completionHandler: @escaping (Data?, Error?) -> Void)
    func write(
        at: URL, content: Data, atomically: Bool, overwrite: Bool,
        completionHandler: @escaping (Error?) -> Void)
}

class FTPFileSystemProvider: FileSystemProvider {

    static var registeredScheme: String = "ftp"

    var fs: FTPFileProvider

    init?(baseURL: URL, cred: URLCredential) {
        guard baseURL.scheme == "ftp" || baseURL.scheme == "ftps" else {
            return nil
        }
        if let fs = FTPFileProvider(baseURL: baseURL, credential: cred) {
            //            fs.serverTrustPolicy = .disableEvaluation
            self.fs = fs
        } else {
            return nil
        }
    }

    func write(
        at: URL, content: Data, atomically: Bool, overwrite: Bool,
        completionHandler: @escaping (Error?) -> Void
    ) {
        fs.writeContents(
            path: at.path, contents: content, atomically: atomically, overwrite: overwrite,
            completionHandler: completionHandler)
    }

    func contentsOfDirectory(at url: URL, completionHandler: @escaping ([URL]?, Error?) -> Void) {
        fs.contentsOfDirectory(path: url.path) { files, error in
            completionHandler(
                files.map {
                    if $0.isDirectory {
                        return $0.url.appendingPathComponent("", isDirectory: true)
                    } else {
                        return $0.url
                    }
                }, error)
        }
    }

    func fileExists(at url: URL, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }

    func createDirectory(
        at: URL, withIntermediateDirectories: Bool, completionHandler: @escaping (Error?) -> Void
    ) {
        fs.create(folder: at.lastPathComponent, at: at.path, completionHandler: completionHandler)
    }

    func copyItem(at: URL, to: URL, completionHandler: @escaping (Error?) -> Void) {
        fs.copyItem(path: at.path, to: to.path, completionHandler: completionHandler)
    }

    func removeItem(at: URL, completionHandler: @escaping (Error?) -> Void) {
        fs.removeItem(path: at.path, completionHandler: completionHandler)
    }

    func contents(at: URL, completionHandler: @escaping (Data?, Error?) -> Void) {
        print("FTP: Loading contents of \(at.path)")
        fs.contents(path: at.path) { data, error in
            print("FTP: Finished loading contents of \(at.absoluteString)")
            DispatchQueue.main.async {
                completionHandler(data, error)
            }
        }
    }

}

class LocalFileSystemProvider: FileSystemProvider {

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

    static var registeredScheme: String = "file"

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

    func removeItem(at: URL, completionHandler: @escaping (Error?) -> Void) {
        do {
            try FileManager.default.removeItem(at: at)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    func contents(at: URL, completionHandler: @escaping (Data?, Error?) -> Void) {
        do {
            let data = try Data(contentsOf: at)
            completionHandler(data, nil)
        } catch {
            completionHandler(nil, error)
        }
    }
}

class WorkSpaceStorage: ObservableObject {
    @Published var currentDirectory: fileItemRepresentable
    @Published var expansionStates: [AnyHashable: Bool] = [:]

    private var directoryMonitor = DirectoryMonitor()
    private var onDirectoryChangeAction: ((String) -> Void)? = nil
    private var directoryStorage: [String: [(fileItemRepresentable)]] = [:]
    private var fss: [String: FileSystemProvider] = [:]

    var remoteConnected: Bool {
        currentDirectory.url.starts(with: "ftp") || currentDirectory.url.starts(with: "ftps")
    }

    var remoteAddress: String? {
        URL(string: currentDirectory.url)?.host
    }

    init(name: String, url: String) {
        self.fss["file"] = LocalFileSystemProvider()
        self.currentDirectory = fileItemRepresentable(name: name, url: url, isDirectory: true)
        self.requestDirectoryUpdateAt(id: url)
    }

    func connectToServer(
        host: URL, credentials: URLCredential, completionHandler: @escaping (Error?) -> Void
    ) {
        switch host.scheme {
        case "ftp", "ftps":
            guard let fs = FTPFileSystemProvider(baseURL: host, cred: credentials) else {
                completionHandler(FSError.invalidHost)
                return
            }
            fs.contentsOfDirectory(at: host) { urls, error in
                if error != nil {
                    completionHandler(error)
                    return
                }
                self.fss["ftp"] = fs
                self.fss["ftps"] = fs
                self.updateDirectory(name: "FTP", url: host.absoluteString)
                completionHandler(nil)
            }
        default:
            return
        }
    }

    func onDirectoryChange(_ action: @escaping ((String) -> Void)) {
        onDirectoryChangeAction = action
    }

    /// Reload the whole directory and invalidate all existing cache
    func updateDirectory(name: String, url: String) {
        if url != currentDirectory.url {
            // Directory is updated
            directoryMonitor.removeAll()
            directoryStorage.removeAll()
            expansionStates.removeAll()
            currentDirectory = fileItemRepresentable(name: name, url: url, isDirectory: true)
            requestDirectoryUpdateAt(id: url)
        } else {
            // Directory is not updated
            let group = DispatchGroup()

            for key in directoryStorage.keys {
                group.enter()
                loadURL(
                    url: key,
                    completionHandler: { items, error in
                        self.directoryStorage[key] = items
                        group.leave()
                    })
            }
            group.wait()

            DispatchQueue.main.async {
                withAnimation(.easeInOut) {
                    self.currentDirectory = self.buildTree(at: url)
                }
            }
        }
    }

    /// Reload a specific subdirectory
    func requestDirectoryUpdateAt(id: String, forceUpdate: Bool = false) {
        guard forceUpdate || !directoryStorage.keys.contains(id) else {
            return
        }
        if !directoryMonitor.keys.contains(id) && id.hasPrefix("file://") {
            directoryMonitor.monitorURL(url: id) {
                self.onDirectoryChangeAction?(id)
                self.requestDirectoryUpdateAt(id: id, forceUpdate: true)
            }
        }

        loadURL(
            url: id,
            completionHandler: { items, error in
                guard let items = items else {
                    return
                }
                self.directoryStorage[id] = items
                DispatchQueue.main.async {
                    withAnimation(.easeInOut) {
                        self.currentDirectory = self.buildTree(at: self.currentDirectory.url)
                    }
                }
            })
    }

    private func buildTree(at base: String) -> fileItemRepresentable {
        let items = directoryStorage[base]
        guard items != nil else {
            return fileItemRepresentable(url: base, isDirectory: true)
        }
        let subItems =
            items!.filter { $0.subFolderItems != nil }.map { buildTree(at: $0.url) }
            + items!.filter { $0.subFolderItems == nil }
        var item = fileItemRepresentable(url: base, isDirectory: true)
        item.subFolderItems = subItems
        return item
    }

    private func loadURL(
        url: String, completionHandler: @escaping ([fileItemRepresentable]?, Error?) -> Void
    ) {
        guard let url = URL(string: url) else {
            completionHandler(nil, nil)
            return
        }

        self.contentsOfDirectory(at: url) { fileURLs, error in
            guard let fileURLs = fileURLs else {
                completionHandler(nil, error)
                return
            }
            var folders: [fileItemRepresentable] = []
            var files: [fileItemRepresentable] = []

            for i in fileURLs {
                var name = i.lastPathComponent.removingPercentEncoding ?? ""
                if name.isEmpty {
                    name = i.host ?? ""
                }
                if i.hasDirectoryPath {
                    folders.append(
                        fileItemRepresentable(name: name, url: i.absoluteString, isDirectory: true))
                } else {
                    files.append(
                        fileItemRepresentable(name: name, url: i.absoluteString, isDirectory: false)
                    )
                }
            }

            files.sort {
                return $0.url.lowercased() < $1.url.lowercased()
            }
            folders.sort {
                return $0.url.lowercased() < $1.url.lowercased()
            }

            completionHandler(folders + files, nil)
        }

    }
}

extension WorkSpaceStorage {
    struct fileItemRepresentable: Identifiable {
        var id: String {
            self.url
        }
        var name: String
        var url: String
        var subFolderItems: [fileItemRepresentable]?

        var isDownloading = false

        init(name: String? = nil, url: String, isDirectory: Bool) {
            if name != nil {
                self.name = name!
            } else if let url = URL(string: url) {
                let displayName = url.lastPathComponent.removingPercentEncoding ?? ""
                if displayName.isEmpty {
                    self.name = url.host ?? ""
                } else {
                    self.name = displayName
                }
            } else {
                self.name = ""
            }
            self.url = url
            if isDirectory {
                subFolderItems = []
            } else {
                subFolderItems = nil
            }
        }
    }
}

extension WorkSpaceStorage: FileSystemProvider {

    static var registeredScheme: String {
        "nil"
    }

    func write(
        at: URL, content: Data, atomically: Bool, overwrite: Bool,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard let scheme = at.scheme, let fs = fss[scheme] else {
            completionHandler(FSError.schemeNotRegistered)
            return
        }
        return fs.write(
            at: at, content: content, atomically: atomically, overwrite: overwrite,
            completionHandler: completionHandler)
    }

    func contentsOfDirectory(at url: URL, completionHandler: @escaping ([URL]?, Error?) -> Void) {
        guard let scheme = url.scheme, let fs = fss[scheme] else {
            completionHandler(nil, FSError.schemeNotRegistered)
            return
        }
        return fs.contentsOfDirectory(at: url, completionHandler: completionHandler)
    }

    func fileExists(at url: URL, completionHandler: @escaping (Bool) -> Void) {
        guard let scheme = url.scheme, let fs = fss[scheme] else {
            completionHandler(false)
            return
        }
        return fs.fileExists(at: url, completionHandler: completionHandler)
    }

    func createDirectory(
        at: URL, withIntermediateDirectories: Bool, completionHandler: @escaping (Error?) -> Void
    ) {
        guard let scheme = at.scheme, let fs = fss[scheme] else {
            completionHandler(FSError.schemeNotRegistered)
            return
        }
        return fs.createDirectory(
            at: at, withIntermediateDirectories: withIntermediateDirectories,
            completionHandler: completionHandler)
    }

    func copyItem(at: URL, to: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let scheme = at.scheme, at.scheme == to.scheme, let fs = fss[scheme] else {
            completionHandler(FSError.schemeNotRegistered)
            return
        }
        return fs.copyItem(at: at, to: to, completionHandler: completionHandler)
    }

    func removeItem(at: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let scheme = at.scheme, let fs = fss[scheme] else {
            completionHandler(FSError.schemeNotRegistered)
            return
        }
        return fs.removeItem(at: at, completionHandler: completionHandler)
    }

    func contents(at: URL, completionHandler: @escaping (Data?, Error?) -> Void) {
        guard let scheme = at.scheme, let fs = fss[scheme] else {
            completionHandler(nil, FSError.schemeNotRegistered)
            return
        }
        return fs.contents(at: at, completionHandler: completionHandler)
    }
}
