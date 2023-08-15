//
//  EditorReadOnlyLabel.swift
//  Code
//
//  Created by Ken Chung on 15/8/2023.
//

import SwiftUI

struct EditorReadOnlyLabel: View {

    @AppStorage("editorReadOnly") var editorReadOnly = false

    var body: some View {
        if editorReadOnly {
            Text("READ-ONLY")
        } else {
            EmptyView()
        }
    }
}
