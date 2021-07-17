//
//  editor.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI
import UniformTypeIdentifiers
import AVKit
import AVFoundation
import UIKit

struct editorView: View{
    @EnvironmentObject var App: MainApp
    
    @AppStorage("editorLightTheme") var editorLightTheme: String = "Default"
    @AppStorage("editorDarkTheme") var editorDarkTheme: String = "Default"
    @Environment (\.colorScheme) var colorScheme: ColorScheme
    
    @Binding var showsNewFile: Bool
    @Binding var showsDirectory: Bool
    @Binding var showsFolderPicker: Bool
    @Binding var showsFilePicker: Bool
    @Binding var directoryID: Int
    @State var targeted: Bool = false
    
    var body: some View{
        HStack(spacing: 0){
            ZStack(){
                Color.init(id: "editor.background")
                if App.editors.isEmpty && App.urlQueue.isEmpty{
                    Text("You don't have any open editor.").foregroundColor(.gray)
                }
                App.monacoInstance
                
                /// We need a way to override WKWebView's DropDelegate
                
//                    .onDrop(of: [UTType.text, UTType.folder], isTargeted: $targeted, perform: { providers in
//                        return true
//                    })
                
                if let editor = App.activeEditor{
                    if editor.type == .preview, let content = App.activeEditor?.content{
                        markDownView(text: content, showsNewFile: $showsNewFile, showsDirectory: $showsDirectory, showsFolderPicker: $showsFolderPicker, showsFilePicker: $showsFilePicker, directoryID: $directoryID)
                    }else if editor.type == .image{
                        ZStack{
                            editor.image!.resizable().scaledToFit()
                                .contextMenu {
                                    Button {
                                        guard let imageURL = URL(string: editor.url), let uiImage = UIImage(contentsOfFile: imageURL.path) else{
                                            return
                                        }
                                        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                                    } label: {
                                        Label("Add to Photos", systemImage: "square.and.arrow.down")
                                    }
                                    Button {
                                        guard let imageURL = URL(string: editor.url), let uiImage = UIImage(contentsOfFile: imageURL.path) else{
                                            return
                                        }
                                        UIPasteboard.general.image = uiImage
                                    } label: {
                                        Label("Copy Image", systemImage: "doc.on.doc")
                                    }
                                }
                        }.frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity).background(Color.init(id: "editor.background"))
                    }else if editor.type == .video{
                        VideoPlayer(player: AVPlayer(url: URL(string: editor.url)!))
                            .onAppear{
                                try? AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [])
                            }
                    }
                }
                
            }
            .onChange(of: colorScheme) { newValue in
                App.updateView()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification), perform: { data in
                if let beginRect = data.userInfo?["UIKeyboardFrameBeginUserInfoKey"] as? CGRect,
                   let endRect = data.userInfo?["UIKeyboardFrameEndUserInfoKey"] as? CGRect{
                    
                    App.saveCurrentFile()
                    
                    monacoWebView.evaluateJavaScript("document.activeElement.className"){result, error in
                        if let res = result as? String{
                            if res != "shadow-root-host" && res != "actions-container" && !res.contains("monaco-list"){
                                if beginRect.origin.y != endRect.origin.y{
                                    App.monacoInstance.executeJavascript(command: "document.getElementById('overlay').focus()")
                                }
                            }
                        }
                    }
                }
            })
            
        }
    }
}
