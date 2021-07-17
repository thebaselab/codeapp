//
//  filePicker.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentPickerView: UIViewControllerRepresentable {
    
    @EnvironmentObject var App: MainApp
    
    func makeCoordinator() -> Coordinator {
        return DocumentPickerView.Coordinator(parent1: self)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.text, UTType.sourceCode, UTType.init("public.data")!])
        documentPicker.allowsMultipleSelection = false
        documentPicker.delegate = context.coordinator
        documentPicker.shouldShowFileExtensions = true
        return documentPicker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate{
        var parent: DocumentPickerView
        var fileQuery: NSMetadataQuery?
        
        init(parent1: DocumentPickerView){
            parent = parent1
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            func saveToTemp(string: String){
                for editor in parent.App.editors {
                    if(editor.url == url.absoluteString){
                        if(parent.App.activeEditor != editor){
                            parent.App.activeEditor = editor
                        }
                        return
                    }
                }
                let newEditor = EditorInstance(url: url.absoluteString, content: string, type: .file)
                parent.App.editors.append(newEditor)
                parent.App.activeEditor = newEditor
                parent.App.monacoInstance.newModel(url: url.absoluteString, content: string)
            }
            
            guard url.startAccessingSecurityScopedResource() else {
                parent.App.notificationManager.showErrorMessage("Permission denied")
                return
            }
            
            if let data = try? Data(contentsOf: url) {
                if let string = String(data: data, encoding: .utf8){
                    saveToTemp(string: string)
                }else{
                    parent.App.notificationManager.showErrorMessage("File not supported")
                }
            }else{
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: url)
                    parent.App.notificationManager.showInformationMessage("Downloading \(url.lastPathComponent)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        if let data = try? Data(contentsOf: url) {
                            if let string = String(data: data, encoding: .utf8){
                                saveToTemp(string: string)
                            }else{
                                self.parent.App.notificationManager.showErrorMessage("File not supported")
                            }
                        }
                    }
                    
//                    let query = NSMetadataQuery()
//                    query.predicate = NSPredicate(format: "%K > 0", NSMetadataUbiquitousItemPercentDownloadedKey)
//                    query.searchScopes = [url.deletingLastPathComponent()]
//                    query.valueListAttributes = [NSMetadataUbiquitousItemPercentDownloadedKey, NSMetadataUbiquitousItemDownloadingStatusKey]
//
//                    fileQuery = query
//
//                    NotificationCenter.default.addObserver(self, selector: #selector(listenForQuery(_:)), name: .NSMetadataQueryDidUpdate, object: query)
//
//                    fileQuery?.start()
                    
                    
                    
                }catch{
                    parent.App.notificationManager.showErrorMessage(error.localizedDescription)
                }
            }
        }
        
        @objc func listenForQuery(_ notification: Notification?){
            let query = notification?.object as? NSMetadataQuery
            
            if query != fileQuery {
                return
            }
            
            if query?.resultCount == 0 {
                return
            }
            
            let item = fileQuery?.result(at: 0) as? NSMetadataItem
            let progress = (item?.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? NSNumber)?.doubleValue ?? 0.0
            print("download progress = \(progress)")
            
        }
    }
}
