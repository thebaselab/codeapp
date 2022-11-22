//
//  VideoViewer.swift
//  Code
//
//  Created by Ken Chung on 22/11/2022.
//

import SwiftUI
import AVKit

private class Storage: ObservableObject {
    @Published var player: AVPlayer? = nil
    @Published var isNonLocalResource: Bool = false
}

private struct VideoView: View {
        
        @EnvironmentObject var storage: Storage
        
        var body: some View {
            if let player = storage.player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                    }
                    .statusBarHidden(false)
            }else if storage.isNonLocalResource {
                Text("External video resource is not supported yet")
            }else {
                Text("Loading Video")
            }
        }
        
}

class VideoViewerExtension: CodeAppExtension {
    
    override func onInitialize(app: MainApp, contribution: CodeAppExtension.Contribution) {
        let provider = EditorProvider(
            registeredFileExtensions: ["mp4", "mov", "m4v", "avi", "mkv", "webm", "wmv", "flv", "mpg", "mpeg", "hevc"],
            onCreateEditor: { url in
                // TODO: Support OutputStream
                let storage = Storage()
                let editorInstance = EditorInstanceWithURL(
                    view: AnyView(VideoView().environmentObject(storage)),
                    title: url.lastPathComponent,
                    url: url
                )

                if url.isFileURL {
                    storage.player = AVPlayer(url: url)
                }else{
                    storage.isNonLocalResource = true
                }

                return editorInstance
            }
        )

        contribution.editorProvider.register(provider: provider)
    }
    
}
