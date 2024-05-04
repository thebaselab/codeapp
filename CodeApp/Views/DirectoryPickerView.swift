//
//  DirectoryPickerView.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum DirectoryPickerViewType {
    case directory, file
}

struct DirectoryPickerView: UIViewControllerRepresentable {

    let type: DirectoryPickerViewType
    let onOpen: ((URL) -> Void)

    func makeCoordinator() -> Coordinator {
        return DirectoryPickerView.Coordinator(parent1: self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(
            forOpeningContentTypes: type == .directory ? [UTType.folder] : [UTType.data])
        documentPicker.allowsMultipleSelection = false
        documentPicker.delegate = context.coordinator
        return documentPicker
    }

    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController, context: Context
    ) {

    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DirectoryPickerView

        init(parent1: DirectoryPickerView) {
            parent = parent1
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
        ) {
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else { return }

            parent.onOpen(url)
        }
    }
}
