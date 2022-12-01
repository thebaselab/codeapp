//
//  ImageViewerExtension.swift
//  Code
//
//  Created by Ken Chung on 22/11/2022.
//

import SwiftUI

private class Storage: ObservableObject {
    @Published var data: Data? = nil
}

private struct ImageContextMenu: View {

    let uiImage: UIImage

    var body: some View {
        Button {
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
        } label: {
            Label("Add to Photos", systemImage: "square.and.arrow.down")
        }
        Button {
            UIPasteboard.general.image = uiImage
        } label: {
            Label("Copy Image", systemImage: "doc.on.doc")
        }

    }

}

private struct ImageView: View {

    @EnvironmentObject var storage: Storage

    var body: some View {
        if let data = storage.data {
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .contextMenu {
                        ImageContextMenu(uiImage: uiImage)
                    }
            } else {
                Text("Unsupported image")
            }
        } else {
            ProgressView()
        }
    }

}

class ImageViewerExtension: CodeAppExtension {

    override func onInitialize(app: MainApp, contribution: CodeAppExtension.Contribution) {
        let provider = EditorProvider(
            registeredFileExtensions: [
                "png", "tiff", "tif", "jpeg", "jpg", "gif", "bmp", "bmp", "BMPf", "ico", "cur",
                "xbm", "heic", "webp",
            ],
            onCreateEditor: { url in
                let storage = Storage()
                let editorInstance = EditorInstanceWithURL(
                    view: AnyView(ImageView().environmentObject(storage)),
                    title: url.lastPathComponent,
                    url: url
                )

                app.workSpaceStorage.contents(
                    at: url,
                    completionHandler: { data, error in
                        storage.data = data
                        if let error {
                            app.notificationManager.showErrorMessage(error.localizedDescription)
                        }
                    })

                return editorInstance
            }
        )
        contribution.editorProvider.register(provider: provider)
    }
}
