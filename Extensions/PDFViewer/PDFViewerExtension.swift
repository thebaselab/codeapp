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
    weak var pdfView: PDFView?
}

private struct PDFKitView: UIViewRepresentable {

    @EnvironmentObject var storage: Storage

    func makeUIView(context: Context) -> PDFView {
        storage.pdfView?.backgroundColor = UIColor(id: "editor.background")
        return storage.pdfView ?? PDFView()
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
            PDFKitView()
        }
    }

}

private class PDFEditorInstance: EditorInstanceWithURL {
    var pdfView: PDFView? = nil
}

class PDFViewerExtension: CodeAppExtension {
    
    private func loadPDFToStorage(url: URL, app: MainApp, storage: Storage){
        app.workSpaceStorage.contents(at: url) {data, error in
            if let data {
                storage.pdfView?.document = PDFDocument(data: data)
            }
            if let error {
                app.notificationManager.showErrorMessage(error.localizedDescription)
            }
            storage.isLoading = false
        }
    }

    override func onInitialize(app: MainApp, contribution: CodeAppExtension.Contribution) {

        let provider = EditorProvider(
            registeredFileExtensions: ["pdf"],
            onCreateEditor: { [weak self] url in
                let pdfView = PDFView()
                let storage = Storage()
                storage.pdfView = pdfView
                let editorInstance = PDFEditorInstance(
                    view: AnyView(PDFUIView().environmentObject(storage).id(UUID())),
                    title: url.lastPathComponent,
                    url: url
                )
                editorInstance.pdfView = pdfView
                
                self?.loadPDFToStorage(url: url, app: app, storage: storage)
                editorInstance.fileWatch?.folderDidChange = { _ in
                    self?.loadPDFToStorage(url: url, app: app, storage: storage)
                }
                editorInstance.fileWatch?.startMonitoring()

                return editorInstance
            }
        )
        contribution.editorProvider.register(provider: provider)
    }
}
