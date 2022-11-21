//
//  DocumentPickerView.swift
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
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [
            UTType.text, UTType.sourceCode, UTType.init("public.data")!,
        ])
        documentPicker.allowsMultipleSelection = false
        documentPicker.delegate = context.coordinator
        documentPicker.shouldShowFileExtensions = true
        return documentPicker
    }

    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController, context: Context
    ) {

    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPickerView
        var fileQuery: NSMetadataQuery?

        init(parent1: DocumentPickerView) {
            parent = parent1
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
        ) {
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                parent.App.notificationManager.showErrorMessage("Permission denied")
                return
            }
            parent.App.openFile(url: url)
        }
    }
}
