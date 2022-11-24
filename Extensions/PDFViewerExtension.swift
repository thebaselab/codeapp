//
//  PDFViewerExtension.swift
//  Code
//
//  Created by Ben Wu on 24/11/2022.
//

import SwiftUI
import PDFKit

private class Storage: ObservableObject {
    @Published var pdfDocument: PDFDocument? = nil
    @Published var isNonLocalResource: Bool = false

}
private struct PDFKitView: UIViewRepresentable{
    
    @EnvironmentObject var storage: Storage
    
    func makeUIView(context:Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = storage.pdfDocument
        pdfView.autoScales = true
        return pdfView
    }
    func updateUIView(_ pdfView: PDFView,context:Context){
        pdfView.document = storage.pdfDocument
    }
    
}
private struct PDFUIView: View {
    
    @EnvironmentObject var storage: Storage
   
    var body: some View {
        PDFKitView()
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
                
                if url.isFileURL {
                    storage.pdfDocument = PDFDocument(url: url)
                }else{
                    storage.isNonLocalResource = true
                }
                
                return editorInstance
            }
        )
        contribution.editorProvider.register(provider: provider)
    }
}
