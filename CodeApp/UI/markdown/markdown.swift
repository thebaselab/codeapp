//
//  markdown.swift
//  Code App
//
//  Created by Ken Chung on 6/12/2020.
//

import SwiftUI
import MarkdownView
import MessageUI

struct changeLogWrapper: View {
    @Environment(\.presentationMode) var presentationMode
    var body: some View{
        NavigationView {
            simpleMarkDownView(text: NSLocalizedString("Changelog.message", comment: ""))
                .navigationBarTitle(NSLocalizedString("Release Notes", comment: ""))
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing:
                                        Button(NSLocalizedString("Done", comment: "")) {
                                            self.presentationMode.wrappedValue.dismiss()
                                        }
                )
        }
    }
}

struct simpleMarkDownView: UIViewRepresentable {
    
    var text: String
    
    func updateUIView(_ uiView: MarkdownView, context: Context) {
    }
    
    func makeUIView(context: Context) -> MarkdownView {
        let md = MarkdownView()
        md.load(markdown: text, backgroundColor: UIColor(Color.init(id: "editor.background")))
        md.onTouchLink = { request in
            guard let url = request.url else { return false }
            UIApplication.shared.open(url)
            return false
        }
        return md
    }
    
}
struct markDownView: UIViewRepresentable {
    
    @EnvironmentObject var App: MainApp
    
    @State var text: String
    
    @Binding var showsNewFile: Bool
    @Binding var showsDirectory: Bool
    @Binding var showsFolderPicker: Bool
    @Binding var showsFilePicker: Bool
    @Binding var directoryID: Int
    
    @State var previousText = ""
    
    func updateUIView(_ uiView: MarkdownView, context: Context) {
        if text != previousText && previousText != ""{
            uiView.load(markdown: text)
        }
        uiView.changeBackgroundColor(color: UIColor(Color.init(id: "editor.background")))
        DispatchQueue.main.async {
            previousText = text
        }
        return
    }
    
    func makeCoordinator() -> markDownView.Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate, MFMailComposeViewControllerDelegate {
        var control: markDownView
        
        init(_ control: markDownView) {
            self.control = control
            super.init()
            
        }
        
    }
    
    func loadMd(md: MarkdownView){
        var recentFolders = "\n"
        var content = self.text
        if let datas = UserDefaults.standard.value(forKey: "recentFolder") as? [Data]{
            for i in datas.indices.reversed(){
                var isStale = false
                if let newURL = try? URL(resolvingBookmarkData: datas[i], bookmarkDataIsStale: &isStale){
                    recentFolders = "\n[\(newURL.lastPathComponent)](https://thebaselab.com/code/previousFolder/\(i))" + recentFolders
                }
            }
            content = self.text.replacingOccurrences(of: "(https://thebaselab.com/code/clone)", with: "(https://thebaselab.com/code/clone)\n\n#### \(NSLocalizedString("Recent", comment: ""))" + recentFolders)
        }
        
        md.load(markdown: content, backgroundColor: UIColor(Color.init(id: "editor.background")))
    }
    
    func makeUIView(context: Context) -> MarkdownView {
        let md = MarkdownView()
        md.changeBackgroundColor(color: UIColor(Color.init(id: "editor.background")))
        md.onTouchLink = { request in
            guard let url = request.url else { return false }
            
            if url.scheme == "file" {
                return false
            } else if url.scheme == "https" || url.scheme == "mailto"{
                switch url.absoluteString{
                case "https://thebaselab.com/code/newfile":
                    self.showsNewFile = true
                case "https://thebaselab.com/code/openfolder":
                    self.showsFolderPicker = true
                case "https://thebaselab.com/code/openfile":
                    self.showsFilePicker = true
                case "https://thebaselab.com/code/clone":
                    self.showsDirectory = true
                    self.directoryID = 3
                case let i where i.hasPrefix("https://thebaselab.com/code/previousFolder/"):
                    let key = Int(i.replacingOccurrences(of: "https://thebaselab.com/code/previousFolder/", with: ""))!
                    if let datas = UserDefaults.standard.value(forKey: "recentFolder") as? [Data]{
                        var isStale = false
                        if let newURL = try? URL(resolvingBookmarkData: datas[key], bookmarkDataIsStale: &isStale){
                            DispatchQueue.main.async {
                                App.loadFolder(url: newURL)
                                self.showsDirectory = true
                            }
                        }
                    }
                default:
                    UIApplication.shared.open(url)
                }
                return false
            } else {
                return false
            }
        }
        loadMd(md: md)
        md.isOpaque = true
        return md
    }
    
}
