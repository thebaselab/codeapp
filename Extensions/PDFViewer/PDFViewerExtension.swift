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
}

private struct PDFKitView: UIViewRepresentable {

    weak var pdfView: PDFView?

    func makeUIView(context: Context) -> PDFView {
        pdfView?.backgroundColor = UIColor(id: "editor.background")
        return pdfView ?? PDFView()
    }
    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.backgroundColor = UIColor(id: "editor.background")
    }

}

private struct PDFUIView: View {

    @EnvironmentObject var storage: Storage
    weak var pdfView: PDFView?

    var body: some View {
        if storage.isLoading {
            ProgressView()
        } else {
            PDFKitView(pdfView: pdfView)
        }
    }

}

private typealias PDFEditorInstance = EditorInstanceWithURL

class PDFViewerExtension: CodeAppExtension {

    override func onInitialize(app: MainApp, contribution: CodeAppExtension.Contribution) {

        let provider = EditorProvider(
            registeredFileExtensions: ["pdf"],
            onCreateEditor: { url in
                let storage = Storage()
                let pdfView = PDFView()
                let editorInstance = PDFEditorInstance(
                    view: AnyView(PDFUIView(pdfView: pdfView).environmentObject(storage)),
                    title: url.lastPathComponent,
                    url: url
                )

                app.workSpaceStorage.contents(at: url) {data, error in
                        if let data {
                            pdfView.document = PDFDocument(data: data)
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
