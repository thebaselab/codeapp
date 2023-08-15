//
//  EncodingMenu.swift
//  Code
//
//  Created by Ken Chung on 1/12/2022.
//

import SwiftUI

struct EncodingMenu: View {

    @EnvironmentObject var App: MainApp

    var body: some View {
        Group {
            if let editor = (App.activeEditor as? TextEditorInstance) {
                MenuButtonView(
                    options: AVAILABLE_ENCODING.map { encoding in
                        MenuButtonView.Option(
                            value: encoding, title: encoding.name,
                            iconSystemName: "textformat")
                    },
                    onSelect: { encoding in
                        App.reloadCurrentFileWithEncoding(encoding: encoding.encoding)
                    },
                    title: (AVAILABLE_ENCODING.first {
                        $0.encoding == editor.encoding
                    })?.name ?? editor.encoding.description,
                    iconName: nil,
                    menuTitle: "file.reopen_with_encoding"
                )
            } else {
                EmptyView()
            }
        }.fixedSize()
    }
}
