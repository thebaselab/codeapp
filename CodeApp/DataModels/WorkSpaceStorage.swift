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
    private var cachedDirectory = Set<String>()
    private var onDirectoryChangeAction: ((String) -> Void)? = nil
    
    var fs: FileSystemProvider = LocalFileSystemProvider()
    
    func onDirectoryChange(_ action: @escaping ((String) -> Void)){
        onDirectoryChangeAction = action
    }
    
    struct fileItemRepresentable: Identifiable {
        var id: String {
            self.url
        }
        var name: String
        var url: String
        var subFolderItems: [fileItemRepresentable]?

        var isDownloading = false

        init(name: String, url: String, isDirectory: Bool){
            self.name = name
            self.url = url
            if isDirectory {
                subFolderItems = []
            }else{
                subFolderItems = nil
            }
        }
    }
    
    func updateDirectory(name: String, url: String){
        cachedDirectory.removeAll()
        DispatchQueue.main.async {
            self.currentDirectory = fileItemRepresentable(name: name, url: url, isDirectory: true)
            self.requestDirectoryUpdateAt(id: url)
        }
    }

    func requestDirectoryUpdateAt(id: String, forceUpdate: Bool = false){
        if !cachedDirectory.contains(id) || forceUpdate{
            let newItems = self.updateSubFolderItemsForId(id: id, item: self.currentDirectory)
            
            DispatchQueue.main.async {
                withAnimation(.easeInOut){
                    self.currentDirectory = newItems
                }
            }
            
            if !cachedDirectory.contains(id){
                directoryMonitor.monitorURL(url: id){
                    self.onDirectoryChangeAction?(id)
                    self.requestDirectoryUpdateAt(id: id, forceUpdate: true)
                }
            }
        }
        
        cachedDirectory.insert(id)
    }

    private func updateSubFolderItemsForId(id: String, item: fileItemRepresentable) -> fileItemRepresentable{
        
        var item = item
        
        if item.id == id {
            // It has been cached
            if !(item.subFolderItems?.isEmpty ?? true) {
                let retainedFolders = item.subFolderItems?.filter({$0.subFolderItems != nil}) ?? []
                var new = loadURL(url: item.url) ?? []
                for i in new.indices {
                    if new[i].subFolderItems != nil {
                        for retainedItem in retainedFolders {
//                            print("\(retainedItem.id) vs \(new[i].id)")
                            if retainedItem.id == new[i].id {
                                new[i].subFolderItems = retainedItem.subFolderItems
                            }
                        }
                    }
                }
                item.subFolderItems = new
            }else{
                var new = loadURL(url: item.url) ?? []
                // Sometimes a folder is expanded but the cache has been removed, we need to update the expanded folders recursively
                for i in new.indices {
                    if (expansionStates[new[i].id] ?? false && new[i].subFolderItems?.isEmpty ?? false) {
                        new[i] = updateSubFolderItemsForId(id: new[i].id, item: new[i])
                    }
                }
                item.subFolderItems = new
            }
            
            return item
        }
        
        if let subItems = item.subFolderItems {
            item.subFolderItems = subItems.map{updateSubFolderItemsForId(id: id, item: $0)}
        }
        
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
