//
//  EncodingMenu.swift
//  Code
//
//  Created by Ken Chung on 1/12/2022.
//

import SwiftUI

struct EncodingMenu: View {

    @EnvironmentObject var App: MainApp
    let editor: TextEditorInstance

    var body: some View {
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
            iconName: nil
        ).fixedSize()

    }
}
