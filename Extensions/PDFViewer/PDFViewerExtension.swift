//
//  PDFViewerExtension.swift
//  Code
//
//  Created by Ben Wu on 24/11/2022.
//

import PDFKit
import SwiftUI

private class Storage: ObservableObject {
    @Published var isLoading: Bool = true

    let pdfView = PDFView()
}

private struct PDFKitView: UIViewRepresentable {

    let pdfView: PDFView

    func makeUIView(context: Context) -> PDFView {
        pdfView.backgroundColor = UIColor(id: "editor.background")
        return pdfView
    }
    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.backgroundColor = UIColor(id: "editor.background")
    }

}

private struct PDFUIView: View {

    @EnvironmentObject var storage: Storage

    var body: some View {
        if storage.isLoading {
            ProgressView()
        } else {
            PDFKitView(pdfView: storage.pdfView)
        }
    }

}

class PDFViewerExtension: CodeAppExtension {

    override func onInitialize(app: MainApp, contribution: CodeAppExtension.Contribution) {

        let provider = EditorProvider(
            registeredFileExtensions: ["pdf"],
            onCreateEditor: { url in
                let storage = Storage()
                let editorInstance = EditorInstanceWithURL(
                    view: AnyView(PDFUIView().environmentObject(storage)),
                    title: url.lastPathComponent,
                    url: url
                )

                app.workSpaceStorage.contents(at: url) { data, error in
                    if let data {
                        storage.pdfView.document = PDFDocument(data: data)
                    }
                    if let error {
                        app.notificationManager.showErrorMessage(error.localizedDescription)
                    }
                    storage.isLoading = false
                }

                return editorInstance
            }
        )
        contribution.editorProvider.register(provider: provider)
    }
}
