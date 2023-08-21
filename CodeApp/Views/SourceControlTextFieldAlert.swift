//
//  SourceControlTextFieldAlert.swift
//  Code
//
//  Created by Ken Chung on 21/8/2023.
//

import SwiftUI

struct SourceControlTextFieldAlert: View {

    @State var value: String = ""

    var textFieldTitle: LocalizedStringKey
    var confirmTitle: LocalizedStringKey

    var onConfirm: (String) -> Void

    var body: some View {
        Group {
            TextField(textFieldTitle, text: $value)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
            Button(confirmTitle) {
                onConfirm(value)
                value = ""
            }
            Button("common.cancel", role: .cancel) {}
        }
    }
}

struct SourceControlDualTextFieldAlert: View {

    @State var value1: String = ""
    @State var value2: String = ""

    var textField1Title: LocalizedStringKey
    var textField2Title: LocalizedStringKey
    var confirmTitle: LocalizedStringKey

    var onConfirm: (String, String) -> Void

    var body: some View {
        Group {
            TextField(textField1Title, text: $value1)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
            TextField(textField2Title, text: $value2)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
            Button(confirmTitle) {
                onConfirm(value1, value2)
                value1 = ""
                value2 = ""
            }
            Button("common.cancel", role: .cancel) {}
        }
    }
}
