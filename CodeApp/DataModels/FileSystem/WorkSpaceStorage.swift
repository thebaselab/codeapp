//
//  WorkSpaceStorage.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import FilesProvider
import Foundation
import SwiftUI

class WorkSpaceStorage: ObservableObject {
    @Published var currentDirectory: fileItemRepresentable
    @Published var expansionStates: [AnyHashable: Bool] = [:]
    @Published var explorerIsBusy = false
    @Published var editorIsBusy = false
    @Published var remoteFingerprint: String? = nil

    private var directoryMonitor = DirectoryMonitor()
    private var onDirectoryChangeAction: ((String) -> Void)? = nil
    private var directoryStorage: [String: [(fileItemRepresentable)]] = [:]
    private var fss: [String: FileSystemProvider] = [:]

    enum FSError: Error {
        case NotImplemented
        case SchemeNotRegistered
        case InvalidHost
        case UnsupportedEncoding
        case Unknown
        case ConnectionFailure
        case AuthFailure
        case UnsupportedScheme

        var message: String {
            switch self {
            case .NotImplemented:
                return ""
            case .SchemeNotRegistered:
                return ""
            case .InvalidHost:
                return ""
            case .UnsupportedEncoding:
                return ""
            case .Unknown:
                return "Unknown Error"
            case .ConnectionFailure:
                return "Connection Failed"
            case .AuthFailure:
                return "Authentication Failed"
            case .UnsupportedScheme:
                return "Unsupported Scheme"
            }
        }
    }

    var remoteConnected: Bool {
        !currentDirectory.url.starts(with: "file")
    }
    var remoteHost: String? {
        URL(string: currentDirectory.url)?.host
    }
    var currentScheme: String? {
        URL(string: currentDirectory.url)?.scheme
    }
    private var fs: FileSystemProvider? {
        currentScheme != nil ? fss[currentScheme!] : nil
    }

    init(url: URL) {
        let localFS = LocalFileSystemProvider()
        localFS.gitServiceProvider = LocalGitServiceProvider(root: url)

        self.fss["file"] = localFS
        self.currentDirectory = fileItemRepresentable(
            name: url.lastPathComponent, url: url.absoluteString, isDirectory: true)
        self.requestDirectoryUpdateAt(id: url.absoluteString)
    }

    func connectToServer(
        host: URL, credentials: URLCredential, completionHandler: @escaping (Error?) -> Void
    ) {
        switch host.scheme {
        case "ftp", "ftps":
            guard let fs = FTPFileSystemProvider(baseURL: host, cred: credentials) else {
                completionHandler(FSError.InvalidHost)
                return
            }
            fs.contentsOfDirectory(at: host) { urls, error in
                if error != nil {
                    completionHandler(error)
                    return
                }
                self.fss[host.scheme!] = fs
                self.updateDirectory(name: "FTP", url: host.absoluteString)
                completionHandler(nil)
            }
        case "sftp":
            guard let password = credentials.password,
                let fs = SFTPFileSystemProvider(
                    baseURL: host, cred: credentials,
                    didDisconnect: { error in
                        self.disconnect()
                    })
            else {
                completionHandler(FSError.Unknown)
                return
            }
            fs.connect(password: password) { error in
                if let error = error {
                    completionHandler(error)
                    return
                }
                guard let homePath = fs.homePath,
                    let hostName = host.host,
                    let baseURL = URL(string: "sftp://\(hostName)/\(homePath)")
                else {
                    completionHandler(FSError.Unknown)
                    return
                }
                fs.contentsOfDirectory(at: baseURL) { urls, error in
                    if error != nil {
                        completionHandler(error)
                        return
                    }
                    self.fss[host.scheme!] = fs
                    self.updateDirectory(name: "SFTP", url: baseURL.absoluteString)

                    if let fingerPrint = fs.fingerPrint {
                        DispatchQueue.main.async {
                            self.remoteFingerprint = fingerPrint
                        }
                    }
                    completionHandler(nil)
                }
            }

        default:
            completionHandler(FSError.UnsupportedScheme)
            return
        }
    }

    func disconnect() {
        expansionStates.removeAll()
        directoryStorage.removeAll()

        fss[currentScheme!] = nil

        let documentDir = getRootDirectory()
        self.currentDirectory = fileItemRepresentable(
            name: documentDir.lastPathComponent, url: documentDir.absoluteString, isDirectory: true)
        self.requestDirectoryUpdateAt(id: documentDir.absoluteString)
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

    private func removeFromTree(url: URL) {
        let isDirectory = url.isDirectory

        if isDirectory {
            directoryStorage.removeValue(forKey: url.absoluteString)
        } else {
            let urlToRemove = url.deletingLastPathComponent()
            directoryStorage[urlToRemove.absoluteString]?.removeAll(where: {
                $0.url == url.absoluteString
            })
        }
        DispatchQueue.main.async {
            withAnimation(.easeInOut) {
                self.currentDirectory = self.buildTree(at: self.currentDirectory.url)
            }
        }
    }

    private func insertToTree(file: fileItemRepresentable) {
        guard var urlToInsert = URL(string: file.url) else {
            return
        }
        urlToInsert.deleteLastPathComponent()
        if directoryStorage[urlToInsert.absoluteString] != nil {
            // Remove duplicated file
            var storage = directoryStorage[urlToInsert.absoluteString]!.filter {
                $0.url != file.url
            }
            storage.append(file)
            directoryStorage[urlToInsert.absoluteString] = storage
        } else {
            directoryStorage[urlToInsert.absoluteString] = [file]
        }
        DispatchQueue.main.async {
            withAnimation(.easeInOut) {
                self.currentDirectory = self.buildTree(at: self.currentDirectory.url)
            }
        }
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

    var gitServiceProvider: GitServiceProvider? {
        fs?.gitServiceProvider
    }

    var searchServiceProvider: SearchServiceProvider? {
        fs?.searchServiceProvider
    }

    func write(
        at: URL, content: Data, atomically: Bool, overwrite: Bool,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard let scheme = at.scheme, let fs = fss[scheme] else {
            completionHandler(FSError.SchemeNotRegistered)
            return
        }
        if scheme != "file" {
            let fileToInsert = fileItemRepresentable(url: at.absoluteString, isDirectory: false)
            insertToTree(file: fileToInsert)
        }
        return fs.write(
            at: at, content: content, atomically: atomically, overwrite: overwrite
        ) { error in
            DispatchQueue.main.async {
                completionHandler(error)
            }
        }
    }

    func contentsOfDirectory(at url: URL, completionHandler: @escaping ([URL]?, Error?) -> Void) {
        guard let scheme = url.scheme, let fs = fss[scheme] else {
            completionHandler(nil, FSError.SchemeNotRegistered)
            return
        }
        DispatchQueue.main.async {
            self.explorerIsBusy = true
        }
        return fs.contentsOfDirectory(at: url) { urls, error in
            DispatchQueue.main.async {
                self.explorerIsBusy = false
            }
            DispatchQueue.main.async {
                completionHandler(urls, error)
            }
        }
    }

    func fileExists(at url: URL, completionHandler: @escaping (Bool) -> Void) {
        guard let scheme = url.scheme, let fs = fss[scheme] else {
            completionHandler(false)
            return
        }
        return fs.fileExists(at: url) { error in
            DispatchQueue.main.async {
                completionHandler(error)
            }
        }
    }

    func createDirectory(
        at: URL, withIntermediateDirectories: Bool, completionHandler: @escaping (Error?) -> Void
    ) {
        guard let scheme = at.scheme, let fs = fss[scheme] else {
            completionHandler(FSError.SchemeNotRegistered)
            return
        }
        if scheme != "file" {
            let fileToInsert = fileItemRepresentable(url: at.absoluteString, isDirectory: true)
            insertToTree(file: fileToInsert)
        }
        return fs.createDirectory(
            at: at, withIntermediateDirectories: withIntermediateDirectories
        ) { error in
            DispatchQueue.main.async {
                completionHandler(error)
            }
        }
    }

    func copyItem(at: URL, to: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let scheme = at.scheme, at.scheme == to.scheme, let fs = fss[scheme] else {
            completionHandler(FSError.SchemeNotRegistered)
            return
        }
        if scheme != "file" {
            let fileToInsert = fileItemRepresentable(url: to.absoluteString, isDirectory: false)
            insertToTree(file: fileToInsert)
        }
        return fs.copyItem(at: at, to: to) { error in
            DispatchQueue.main.async {
                completionHandler(error)
            }
        }
    }

    func removeItem(at: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let scheme = at.scheme, let fs = fss[scheme] else {
            completionHandler(FSError.SchemeNotRegistered)
            return
        }
        return fs.removeItem(at: at) { error in
            if scheme != "file" && error == nil {
                self.removeFromTree(url: at)
            }
            DispatchQueue.main.async {
                completionHandler(error)
            }
        }
    }

    func contents(at: URL, completionHandler: @escaping (Data?, Error?) -> Void) {
        guard let scheme = at.scheme, let fs = fss[scheme] else {
            completionHandler(nil, FSError.SchemeNotRegistered)
            return
        }
        DispatchQueue.main.async {
            self.editorIsBusy = true
        }
        return fs.contents(at: at) { data, error in
            DispatchQueue.main.async {
                self.editorIsBusy = false
                completionHandler(data, error)
            }
        }
    }
}
