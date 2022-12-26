//
//  File.swift
//  Code
//
//  Created by Ben Wu on 26/12/2022.
//

import SwiftUI

class EncodingErrorEditorInstance: EditorInstance {

}
struct EncodingErrorEditorView: View {
    @EnvironmentObject var App: MainApp
    let url: URL
    init(url: URL) {
        self.url = url
    }
    var body: some View {
        VStack {
            Label("Unknown Encoding", systemImage: "exclamationmark.triangle.fill")
            Menu {
                ForEach(AVAILABLE_ENCODING) { encoding in

                    Button(
                        encoding.name,
                        action: {
                            Task {
                                try await App.openFile(
                                    url: url, alwaysInNewTab: false, encoding: encoding.encoding)

                            }

                        })
                }
            } label: {
                Text("Open file in encoding...").foregroundColor(.blue)
            }

        }

    }
}

