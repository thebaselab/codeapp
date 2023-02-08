//
//  SettingsView.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var AppStore: Store

    @AppStorage("editorFontSize") var fontSize: Int = 14
    @AppStorage("editorFontFamily") var fontFamily: String = "Menlo"
    @AppStorage("fontLigatures") var fontLigatures: Bool = false
    @AppStorage("quoteAutoCompletionEnabled") var quoteAutoCompleteEnabled: Bool = true
    @AppStorage("suggestionEnabled") var suggestionEnabled: Bool = true
    @AppStorage("editorMiniMapEnabled") var miniMapEnabled: Bool = true
    @AppStorage("editorLineNumberEnabled") var editorLineNumberEnabled: Bool = true
    @AppStorage("editorShowKeyboardButtonEnabled") var editorShowKeyboardButtonEnabled: Bool = true
    @AppStorage("editorTabSize") var edtorTabSize: Int = 4
    @AppStorage("consoleFontSize") var consoleFontSize: Int = 14
    @AppStorage("preferredColorScheme") var preferredColorScheme: Int = 0
    @AppStorage("editorRenderWhitespace") var renderWhitespace: Int = 2
    @AppStorage("editorWordWrap") var editorWordWrap: String = "off"
    @AppStorage("explorer.showHiddenFiles") var showHiddenFiles: Bool = false
    @AppStorage("toolBarEnabled") var toolBarEnabled: Bool = true
    @AppStorage("alwaysOpenInNewTab") var alwaysOpenInNewTab: Bool = false
    @AppStorage("editorSmoothScrolling") var editorSmoothScrolling: Bool = false
    @AppStorage("editorReadOnly") var editorReadOnly = false
    @AppStorage("stateRestorationEnabled") var stateRestorationEnabled = true
    @AppStorage("compilerShowPath") var compilerShowPath = false
    @AppStorage("editorSpellCheckEnabled") var editorSpellCheckEnabled = false
    @AppStorage("editorSpellCheckOnContentChanged") var editorSpellCheckOnContentChanged = true
    @AppStorage("communityTemplatesEnabled") var communityTemplatesEnabled = true
    @AppStorage("showAllFonts") var showAllFonts = false

    @State var showsEraseAlert: Bool = false
    @State var showReceiptInformation: Bool = false

    let colorSchemes = ["Automatic", "Dark", "Light"]
    let renderWhitespaceOptions = ["None", "Boundary", "Selection", "Trailing", "All"]
    let wordWrapOptions = ["off", "on", "wordWrapColumn", "bounded"]

    @Environment(\.presentationMode) var presentationMode
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        NavigationView {
            Form {
                // TODO: Rework Editor / Terminal settings to support multiple scenes

                Section(header: Text(NSLocalizedString("General", comment: ""))) {

                    NavigationLink(
                        destination:
                            SettingsThemeConfiguration()
                            .environmentObject(App)
                    ) {
                        Text("Themes")
                    }

                    Picker(selection: $preferredColorScheme, label: Text("Color Scheme")) {
                        ForEach(0..<colorSchemes.count, id: \.self) {
                            Text(self.colorSchemes[$0])
                        }
                    }
                    Stepper(
                        "\(NSLocalizedString("Editor Font Size", comment: "")) (\(fontSize))",
                        value: $fontSize, in: 10...30
                    ).onChange(of: fontSize) { value in
                        App.monacoInstance.executeJavascript(
                            command: "editor.updateOptions({fontSize: \(String(value))})")
                    }

                    Stepper(
                        "\(NSLocalizedString("Console Font Size", comment: "")) (\(consoleFontSize))",
                        value: $consoleFontSize, in: 8...24)

                    Button(action: {
                        guard let url = URL(string: "https://github.com/thebaselab/codeapp")
                        else { return }
                        UIApplication.shared.open(url)
                    }) {
                        Text("Open an issue on GitHub")
                    }

                    Button(action: {
                        guard let url = URL(string: "mailto:support@thebaselab.com")
                        else { return }
                        UIApplication.shared.open(url)
                    }) {
                        Text("Send us an email")
                    }

                    Button(action: {
                        guard
                            let writeReviewURL = URL(
                                string:
                                    "https://apps.apple.com/app/id1512938504?action=write-review")
                        else { return }
                        UIApplication.shared.open(writeReviewURL)
                    }) {
                        Text(NSLocalizedString("Rate Code App", comment: ""))
                    }
                }

                Section(header: Text(NSLocalizedString("Version Control", comment: ""))) {
                    NavigationLink(destination: SourceControlIdentityConfiguration()) {
                        Text("Author Identity")
                    }
                    NavigationLink(destination: SourceControlAuthenticationConfiguration()) {
                        Text("Authentication")
                    }
                    Toggle("source_control.community_templates", isOn: $communityTemplatesEnabled)
                }

                Section(header: Text(NSLocalizedString("EXPLORER", comment: ""))) {
                    Toggle(
                        NSLocalizedString("Show hidden files", comment: ""), isOn: $showHiddenFiles)
                }

                Section(header: Text(NSLocalizedString("Editor", comment: ""))) {

                    NavigationLink(
                        destination: SettingsFontPicker(
                            showAllFonts: showAllFonts,
                            onFontPick: { descriptor in
                                fontFamily = descriptor.object(forKey: .family) as! String
                            }
                        ).toolbar {
                            Button("settings.editor.font.reset") {
                                fontFamily = "Menlo"
                            }
                            .disabled(fontFamily == "Menlo")
                        },
                        label: {
                            HStack {
                                Text("settings.editor.font")
                                Spacer()
                                Text(fontFamily)
                                    .foregroundColor(.gray)
                            }
                        }
                    )
                    .onChange(of: fontFamily) { value in
                        App.monacoInstance.executeJavascript(
                            command: "editor.updateOptions({fontFamily: \"\(value)\"})")
                    }

                    Toggle("settings.editor.font.show_all_fonts", isOn: $showAllFonts)

                    Toggle("settings.editor.font.ligatures", isOn: $fontLigatures)
                        .onChange(of: fontLigatures) { value in
                            App.monacoInstance.executeJavascript(
                                command: "editor.updateOptions({fontLigatures: \(value)})")
                        }

                    NavigationLink(
                        destination:
                            SettingsKeyboardShortcuts()
                            .environmentObject(App)
                    ) {
                        Text("Custom Keyboard Shortcuts")
                    }

                    Group {
                        Stepper(
                            "\(NSLocalizedString("Tab Size", comment: "")) (\(edtorTabSize))",
                            value: $edtorTabSize, in: 1...8
                        ).onChange(of: edtorTabSize) { value in
                            App.monacoInstance.executeJavascript(
                                command: "editor.updateOptions({tabSize: \(String(value))})")
                        }
                    }

                    Group {
                        Toggle("Read-only Mode", isOn: self.$editorReadOnly).onChange(
                            of: editorReadOnly
                        ) { value in
                            App.monacoInstance.executeJavascript(
                                command: "editor.updateOptions({ readOnly: \(String(value)) })")
                        }
                        Toggle("UI State Restoration", isOn: self.$stateRestorationEnabled)
                    }

                    Group {
                        Toggle(
                            NSLocalizedString("Bracket Completion", comment: ""),
                            isOn: self.$quoteAutoCompleteEnabled
                        ).onChange(of: quoteAutoCompleteEnabled) { value in
                            App.monacoInstance.executeJavascript(
                                command:
                                    "editor.updateOptions({ autoClosingBrackets: \(String(value)) })"
                            )
                        }

                        Toggle(
                            NSLocalizedString("Mini Map", comment: ""), isOn: self.$miniMapEnabled
                        ).onChange(of: miniMapEnabled) { value in
                            App.monacoInstance.executeJavascript(
                                command:
                                    "editor.updateOptions({minimap: {enabled: \(String(value))}})")
                        }

                        Toggle(
                            NSLocalizedString("Line Numbers", comment: ""),
                            isOn: self.$editorLineNumberEnabled
                        ).onChange(of: editorLineNumberEnabled) { value in
                            App.monacoInstance.executeJavascript(
                                command: "editor.updateOptions({ lineNumbers: \(String(value)) })")
                        }

                        Toggle(
                            "Keyboard Toolbar (Effective in next launch)",
                            isOn: self.$toolBarEnabled
                        ).onChange(
                            of: toolBarEnabled
                        ) { value in
                            NotificationCenter.default.post(
                                name: Notification.Name("toolbarSettingChanged"), object: nil,
                                userInfo: ["enabled": value])
                        }

                        Toggle("Always Open In New Tab", isOn: self.$alwaysOpenInNewTab)

                        Toggle(
                            NSLocalizedString("Smooth Scrolling", comment: ""),
                            isOn: self.$editorSmoothScrolling
                        ).onChange(of: editorSmoothScrolling) { value in
                            App.monacoInstance.executeJavascript(
                                command:
                                    "editor.updateOptions({ smoothScrolling: \(String(value)) })")
                        }
                    }

                    Group {
                        Picker(
                            NSLocalizedString("Text Wrap", comment: ""), selection: $editorWordWrap
                        ) {
                            ForEach(self.wordWrapOptions, id: \.self) {
                                Text("\($0)")
                            }
                        }.onChange(of: editorWordWrap) { value in
                            App.monacoInstance.executeJavascript(
                                command: "editor.updateOptions({wordWrap: '\(editorWordWrap)'})")
                        }

                        Picker(selection: $renderWhitespace, label: Text("Render Whitespace")) {
                            ForEach(0..<renderWhitespaceOptions.count, id: \.self) {
                                Text(self.renderWhitespaceOptions[$0])
                            }
                        }.onChange(of: renderWhitespace) { value in
                            App.monacoInstance.executeJavascript(
                                command:
                                    "editor.updateOptions({renderWhitespace: '\(String(renderWhitespaceOptions[renderWhitespace]).lowercased())'})"
                            )
                        }
                    }
                }

                Section(header: Text("local.execution.title")) {
                    Toggle("Show Command in Terminal", isOn: $compilerShowPath)
                }

                Section("Experimental Features") {
                    Toggle("Enable spell check in text files", isOn: $editorSpellCheckEnabled)
                    if editorSpellCheckEnabled {
                        Toggle(
                            "Spell checking on content changed",
                            isOn: $editorSpellCheckOnContentChanged)
                    }
                }

                Section(header: Text(NSLocalizedString("About", comment: ""))) {

                    NavigationLink(
                        destination: SimpleMarkDownView(
                            text: NSLocalizedString("Changelog.message", comment: ""))
                    ) {
                        Text(NSLocalizedString("Release Notes", comment: ""))
                    }

                    if AppStore.isSubscribed {
                        Button("Request a refund") {
                            AppStore.beginRefundProcess()
                        }
                    }

                    Button(action: {
                        showsEraseAlert.toggle()
                    }) {
                        Text(NSLocalizedString("Erase all settings", comment: "")).foregroundColor(
                            .red)
                    }
                    .alert(isPresented: $showsEraseAlert) {
                        Alert(
                            title: Text(NSLocalizedString("Erase all settings", comment: "")),
                            message: Text(
                                NSLocalizedString(
                                    "This will erase all user settings, including author identity and credentials.",
                                    comment: "")),
                            primaryButton: .destructive(
                                Text(NSLocalizedString("Erase", comment: ""))
                            ) {
                                UserDefaults.standard.dictionaryRepresentation().keys.forEach {
                                    key in
                                    UserDefaults.standard.removeObject(forKey: key)
                                }
                                KeychainWrapper.standard.set("", forKey: "git-username")
                                KeychainWrapper.standard.set("", forKey: "git-password")
                                NSUserActivity.deleteAllSavedUserActivities {}
                                App.notificationManager.showInformationMessage(
                                    "All settings erased")
                            }, secondaryButton: .cancel())
                    }
                    Link(
                        "terms_of_use",
                        destination: URL(
                            string:
                                "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
                    )
                    Link(
                        "code.and.privacy",
                        destination: URL(string: "https://thebaselab.com/privacypolicies/")!)

                    NavigationLink(
                        destination: SimpleMarkDownView(
                            text: NSLocalizedString("licenses", comment: ""))
                    ) {
                        Text("Licenses")
                    }
                    HStack {
                        Text(NSLocalizedString("Version", comment: ""))
                        Spacer()
                        Text(
                            (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                                ?? "0.0") + " Build "
                                + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0")
                        )
                    }

                    if showReceiptInformation {
                        HStack {
                            Text("Receipt - Original app version")
                            Spacer()
                            Text("\(AppStore.purchaseReceipt?.originalAppVersion ?? "None")")
                        }

                        HStack {
                            Text("Receipt - TestFlight")
                            Spacer()
                            Text(
                                Bundle.main.appStoreReceiptURL?.lastPathComponent
                                    == "sandboxReceipt" ? "True" : "False")
                        }
                    }

                    Text("Code App by thebaselab").font(.footnote).foregroundColor(.gray)
                        .onTapGesture(
                            count: 2,
                            perform: {
                                showReceiptInformation = true
                            })
                }

            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitle("Settings", displayMode: .inline)
            .navigationBarItems(
                trailing:
                    Button(NSLocalizedString("Done", comment: "")) {
                        self.presentationMode.wrappedValue.dismiss()
                    }
            )
        }
    }
}
