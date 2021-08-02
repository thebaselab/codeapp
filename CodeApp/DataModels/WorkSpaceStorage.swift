//
//  WorkSpaceStorage.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import Foundation
import SwiftUI

enum FSError: Error {
    case notImplemented
}

protocol FileSystemProvider {
    static var registeredScheme: String {get}
    
    func contentsOfDirectory(at url: URL) throws -> [URL]
    func fileExists(atPath path: String) -> Bool
    func createDirectory(at: URL, withIntermediateDirectories: Bool) throws
    func copyItem(at: URL, to: URL) throws
    func removeItem(at: URL) throws
    func contents(at: URL) throws -> Data
}

class SSHFileSystemProvider: FileSystemProvider {
    static var registeredScheme: String = "ssh"
    
    var executor: Executor? = nil
    
    private var tempResponse = ""
    
    init (){
        executor = Executor(root: URL(fileURLWithPath: FileManager().currentDirectoryPath), onStdout: {data in
            if let mes = String(data: data, encoding: .utf8){
                self.tempResponse += mes
            }
        }, onStderr: {data in
            if let mes = String(data: data, encoding: .utf8){
                self.tempResponse += mes
            }
        }, onRequestInput: {_ in})
    }
    
    
    func contentsOfDirectory(at url: URL) throws -> [URL] {
        throw FSError.notImplemented
    }
    
    func fileExists(atPath path: String) -> Bool {
        return false
    }
    
    func createDirectory(at: URL, withIntermediateDirectories: Bool) throws {
        throw FSError.notImplemented
    }
    
    func copyItem(at: URL, to: URL) throws {
        throw FSError.notImplemented
    }
    
    func removeItem(at: URL) throws {
        throw FSError.notImplemented
    }
    
    func contents(at: URL) throws -> Data {
        throw FSError.notImplemented
    }
    
}

class LocalFileSystemProvider: FileSystemProvider {
    static var registeredScheme: String = "file"
    
    func contentsOfDirectory(at url: URL) throws -> [URL] {
        return try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    }
    
    func fileExists(atPath path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    func createDirectory(at: URL, withIntermediateDirectories: Bool) throws {
        try FileManager.default.createDirectory(at: at, withIntermediateDirectories: withIntermediateDirectories)
    }
    
    func copyItem(at: URL, to: URL) throws {
        try FileManager.default.copyItem(at: at, to: to)
    }
    
    func removeItem(at: URL) throws {
        try FileManager.default.removeItem(at: at)
    }
    
    func contents(at: URL) throws -> Data {
        return try Data(contentsOf: at)
    }
    
}

class WorkSpaceStorage: ObservableObject{
    @Published var currentDirectory: fileItemRepresentable
    @Published var expansionStates: [AnyHashable:Bool] = [:]
    
    private var directoryMonitor = DirectoryMonitor()
    private var trackedDirectory = Set<String>()
    private var onDirectoryChangeAction: ((String) -> Void)? = nil
    private var directoryStorage: [String: [(fileItemRepresentable)]] = [:]
    
    var fs: FileSystemProvider = LocalFileSystemProvider()
    
    func onDirectoryChange(_ action: @escaping ((String) -> Void)){
        onDirectoryChangeAction = action
    }
    
    /// Reload the whole directory and invalidate all existing cache
    func updateDirectory(name: String, url: String){
        trackedDirectory.removeAll()
        DispatchQueue.main.async {
            self.currentDirectory = fileItemRepresentable(name: name, url: url, isDirectory: true)
            self.requestDirectoryUpdateAt(id: url)
        }
    }
    
    /// Reload a specific subdirectory
    func requestDirectoryUpdateAt(id: String, forceUpdate: Bool = false){
        guard forceUpdate || !directoryStorage.keys.contains(id) else {
            return
        }
        if !directoryStorage.keys.contains(id) {
            directoryMonitor.monitorURL(url: id){
                self.onDirectoryChangeAction?(id)
                self.requestDirectoryUpdateAt(id: id, forceUpdate: true)
            }
        }
        
        if let items = loadURL(url: id) {
            directoryStorage[id] = items
            DispatchQueue.main.async {
                withAnimation(.easeInOut){
                    self.currentDirectory = self.buildTree(at: self.currentDirectory.url)
                }
            }
        }
    }

    private func buildTree(at base: String) -> fileItemRepresentable{
        let items = directoryStorage[base]
        guard items != nil else {
            return fileItemRepresentable(url: base, isDirectory: true)
        }
        let subItems = items!.filter{$0.subFolderItems != nil}.map{buildTree(at: $0.url)} + items!.filter{$0.subFolderItems == nil}
        var item = fileItemRepresentable(url: base, isDirectory: true)
        item.subFolderItems = subItems
        return item
    }

    private func loadURL(url: String) -> [fileItemRepresentable]?{
        print("Starting loadURL: \(url)")

        guard let url = URL(string: url) else{
            return nil
        }

        var folders: [fileItemRepresentable] = []
        var files: [fileItemRepresentable] = []

        do {
            let fileURLs = try fs.contentsOfDirectory(at: url)

            for i in fileURLs{

                if(i.hasDirectoryPath){
                    folders.append(fileItemRepresentable(name: i.lastPathComponent.removingPercentEncoding ?? "", url: i.absoluteString, isDirectory: true))
                }else{
                    files.append(fileItemRepresentable(name: i.lastPathComponent.removingPercentEncoding ?? "", url: i.absoluteString, isDirectory: false))
                }
            }
        } catch {
            print("Error while enumerating files \(url.path): \(error.localizedDescription)")
            return nil
        }
        files.sort{
            return $0.url.lowercased() < $1.url.lowercased()
        }
        folders.sort{
            return $0.url.lowercased() < $1.url.lowercased()
        }
        print("Finished loadURL: \(url)")
        return folders + files
    }

    init(name: String, url: String){
        self.currentDirectory = fileItemRepresentable(name: name, url: url, isDirectory: true)
        self.requestDirectoryUpdateAt(id: url)
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

        init(name: String? = nil, url: String, isDirectory: Bool){
            if name != nil {
                self.name = name!
            }else if let url = URL(string: url){
                self.name = url.lastPathComponent.removingPercentEncoding ?? ""
            }else{
                self.name = ""
            }
            self.url = url
            if isDirectory {
                subFolderItems = []
            }else{
                subFolderItems = nil
            }
        }
    }
}
