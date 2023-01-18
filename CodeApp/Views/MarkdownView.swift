//
//  markdown.swift
//  Code App
//
//  Created by Ken Chung on 6/12/2020.
//

import MarkdownView
import MessageUI
import SwiftUI

struct SimpleMarkDownView: UIViewRepresentable {

    var text: String

    func updateUIView(_ uiView: MarkdownView, context: Context) {
        uiView.changeBackgroundColor(color: UIColor(id: "editor.background"))
    }

    func makeUIView(context: Context) -> MarkdownView {
        let md = MarkdownView()
        md.load(markdown: text, backgroundColor: UIColor(id: "editor.background"))
        md.onTouchLink = { request in
            guard let url = request.url else { return false }
            UIApplication.shared.open(url)
            return false
        }
        return md
    }
}

struct ChangeLogView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            SimpleMarkDownView(text: NSLocalizedString("Changelog.message", comment: ""))
                .navigationBarTitle("Release Notes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Done")
                            .foregroundColor(.blue)
                            .font(.body)
                    }

                }
        }
    }
}

struct WelcomeView: UIViewRepresentable {
    let onCreateNewFile: () -> Void
    let onSelectFolderAsWorkspaceStorage: (URL) -> Void
    let onSelectFolder: () -> Void
    let onSelectFile: () -> Void
    let onNavigateToCloneSection: () -> Void

    func updateUIView(_ uiView: MarkdownView, context: Context) {
        uiView.changeBackgroundColor(color: UIColor(Color.init(id: "editor.background")))
        return
    }

    func makeCoordinator() -> WelcomeView.Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate, MFMailComposeViewControllerDelegate {
        var control: WelcomeView

        init(_ control: WelcomeView) {
            self.control = control
            super.init()

        }

    }

    func loadMd(md: MarkdownView) {
        var content = NSLocalizedString("Welcome Message", comment: "")
        if let datas = UserDefaults.standard.value(forKey: "recentFolder") as? [Data] {
            var recentFolders = "\n"

            for i in datas.indices.reversed() {
                var isStale = false
                if let newURL = try? URL(
                    resolvingBookmarkData: datas[i], bookmarkDataIsStale: &isStale)
                {
                    recentFolders =
                        "\n[\(newURL.lastPathComponent)](https://thebaselab.com/code/previousFolder/\(i))"
                        + recentFolders
                }
            }
            content = content.replacingOccurrences(
                of: "(https://thebaselab.com/code/openfolder)",
                with:
                    "(https://thebaselab.com/code/openfolder)\n\n#### \(NSLocalizedString("Recent", comment: ""))"
                    + recentFolders)
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
            } else if url.scheme == "https" || url.scheme == "mailto" {
                switch url.absoluteString {
                case "https://thebaselab.com/code/newfile":
                    onCreateNewFile()
                case "https://thebaselab.com/code/openfolder":
                    onSelectFolder()
                case "https://thebaselab.com/code/openfile":
                    onSelectFile()
                case "https://thebaselab.com/code/clone":
                    onNavigateToCloneSection()
                case let i where i.hasPrefix("https://thebaselab.com/code/previousFolder/"):
                    let key = Int(
                        i.replacingOccurrences(
                            of: "https://thebaselab.com/code/previousFolder/", with: ""))!
                    if let datas = UserDefaults.standard.value(forKey: "recentFolder") as? [Data] {
                        var isStale = false
                        if let newURL = try? URL(
                            resolvingBookmarkData: datas[key], bookmarkDataIsStale: &isStale)
                        {
                            onSelectFolderAsWorkspaceStorage(newURL)
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
