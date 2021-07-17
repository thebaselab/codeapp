//
//  EditorInstance.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import Foundation
import SwiftUI

class EditorInstance: Identifiable, Equatable, Hashable {
    
    static func == (lhs: EditorInstance, rhs: EditorInstance) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var id = UUID()
    var url: String
    var content: String
    var lastSavedVersionId = 1
    var currentVersionId = 1
    
    let type: tabType
    
    var compareTo: String? = nil
    var image: Image? = nil
    
    var encoding: String.Encoding = .utf8
    
    var fileWatch: FolderMonitor?
    var isDeleted = false
    
    init(url: String, content: String, type: tabType, encoding: String.Encoding = .utf8, compareTo: String? = nil, image: Image? = nil, fileDidChange: ((fileState, String?) -> Void)? = nil){
        self.url = url
        self.content = content
        self.type = type
        self.encoding = encoding
        self.compareTo = compareTo
        self.image = image
        
//        if let url = URL(string: url), let attr = try? FileManager.default.attributesOfItem(atPath: url.path), let modificationDate = attr[FileAttributeKey.modificationDate] as? Date {
//            self.lastSavedDate = modificationDate
//        }
        
        if fileDidChange != nil, let url = URL(string: url) {
            self.fileWatch = FolderMonitor(url: url)
            
            self.fileWatch?.folderDidChange = {
                
                // This doesn't work for some reason.
//                if !FileManager.default.fileExists(atPath: url.path){
//                    fileDidChange?(.deleted, nil)
//                    DispatchQueue.main.async {
//                        print("\(url.path) delted!")
//                        self.isDeleted = true
//                    }
//
//                    return
//                }
                
//                guard let attr = try? FileManager.default.attributesOfItem(atPath: url.path), let modificationDate = attr[FileAttributeKey.modificationDate] as? Date else{
//                    return
//                }
                
                if let content = try? String(contentsOf: url, encoding: self.encoding){
                    
                    if self.lastSavedVersionId == self.currentVersionId {
                        self.content = content
                        fileDidChange?(.modified, content)
                        self.lastSavedVersionId = self.currentVersionId
                    }
                    
                    
                }
            }
            
            self.fileWatch?.startMonitoring()
        }
        
    }
    
    deinit{
        self.fileWatch?.stopMonitoring()
    }
    
//    enum fileOperationError: Error {
//        case contentOnDiskIsNewer
//    }
    
    enum fileState{
        case deleted
        case modified
    }
    
    enum tabType {
        case file
        case preview
        case diff
        case image
        case video
        case any
    }
}
