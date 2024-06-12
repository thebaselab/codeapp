//
//  SettingsView.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var themeManager: ThemeManager

    @AppStorage("suggestionEnabled") var suggestionEnabled: Bool = true
    @AppStorage("editorShowKeyboardButtonEnabled") var editorShowKeyboardButtonEnabled: Bool = true
    @AppStorage("consoleFontSize") var consoleFontSize: Int = 14
    @AppStorage("terminalToolBarEnabled") var terminalToolBarEnabled: Bool = true
    @AppStorage("preferredColorScheme") var preferredColorScheme: Int = 0
    @AppStorage("explorer.showHiddenFiles") var showHiddenFiles: Bool = false
    @AppStorage("explorer.confirmBeforeDelete") var confirmBeforeDelete = false
    @AppStorage("alwaysOpenInNewTab") var alwaysOpenInNewTab: Bool = false
    @AppStorage("stateRestorationEnabled") var stateRestorationEnabled = true
    @AppStorage("compilerShowPath") var compilerShowPath = false
    @AppStorage("communityTemplatesEnabled") var communityTemplatesEnabled = true
    @AppStorage("showAllFonts") var showAllFonts = false
    @AppStorage("remoteShouldResolveHomePath") var remoteShouldResolveHomePath = false
    @AppStorage("editorOptions") var editorOptions: CodableWrapper<EditorOptions> = .init(
        value: EditorOptions())
    @AppStorage("runeStoneEditorEnabled") var runeStoneEditorEnabled: Bool = false

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

                Group {
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
                            "\(NSLocalizedString("Editor Font Size", comment: "")) (\(editorOptions.value.fontSize))",
                            value: $editorOptions.value.fontSize, in: 10...30
                        )

                        Stepper(
                            "\(NSLocalizedString("Console Font Size", comment: "")) (\(consoleFontSize))",
                            value: $consoleFontSize, in: 8...24)

                        Button(action: {
                            guard let url = URL(string: "https://github.com/thebaselab/codeapp")
                            else { return }
                            UIApplication.shared.open(url)
                        }) {
                            Text("Open an Issue on GitHub")
                        }

                        Button(action: {
                            guard let url = URL(string: "mailto:support@thebaselab.com")
                            else { return }
                            UIApplication.shared.open(url)
                        }) {
                            Text("Send us an Email")
                        }

                        Button(action: {
                            guard
                                let writeReviewURL = URL(
                                    string:
                                        "https://apps.apple.com/app/id1512938504?action=write-review"
                                )
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
                        Toggle(
                            "source_control.community_templates", isOn: $communityTemplatesEnabled)
                    }

                    Section("remote.settings.ssh_remote") {
                        Toggle(
                            "remote.settings.resolve_home_path", isOn: $remoteShouldResolveHomePath)
                    }

                    Section(header: Text(NSLocalizedString("EXPLORER", comment: ""))) {
                        Toggle("settings.explorer.show_hidden_files", isOn: $showHiddenFiles)
                        Toggle(
                            "settings.explorer.confirm_before_delete", isOn: $confirmBeforeDelete)
                    }

                    Section(header: Text(NSLocalizedString("Editor", comment: ""))) {

                        Toggle("settings.editor.vim.enabled", isOn: $editorOptions.value.vimEnabled)

                        NavigationLink(
                            destination: SettingsFontPicker(
                                showAllFonts: showAllFonts,
                                onFontPick: { descriptor in
                                    CTFontManagerRequestFonts([descriptor] as CFArray) { _ in
                                        editorOptions.value.fontFamily =
                                            descriptor.object(forKey: .family) as! String
                                    }
                                }
                            ).toolbar {
                                Button("settings.editor.font.reset") {
                                    editorOptions.value.fontFamily = "Menlo"
                                }
                                .disabled(editorOptions.value.fontFamily == "Menlo")
                            },
                            label: {
                                HStack {
                                    Text("settings.editor.font")
                                    Spacer()
                                    Text(editorOptions.value.fontFamily)
                                        .foregroundColor(.gray)
                                }
                            }
                        )

                        Toggle("settings.editor.font.show_all_fonts", isOn: $showAllFonts)

                        Toggle(
                            "settings.editor.font.ligatures",
                            isOn: $editorOptions.value.fontLigaturesEnabled)

                        NavigationLink(
                            destination:
                                SettingsKeyboardShortcuts()
                                .environmentObject(App)
                        ) {
                            Text("Custom Keyboard Shortcuts")
                        }

                        Group {
                            Stepper(
                                "\(NSLocalizedString("Tab Size", comment: "")) (\(editorOptions.value.tabRenderSize))",
                                value: $editorOptions.value.tabRenderSize, in: 1...8
                            )
                        }

                        Group {
                            Toggle("Read-only Mode", isOn: $editorOptions.value.readOnly)
                            Toggle("UI State Restoration", isOn: self.$stateRestorationEnabled)
                        }

                        Group {
                            Toggle(
                                NSLocalizedString("Bracket Completion", comment: ""),
                                isOn: $editorOptions.value.autoClosingBrackets
                            )

                            Toggle(
                                NSLocalizedString("Mini Map", comment: ""),
                                isOn: $editorOptions.value.miniMapEnabled
                            )

                            Toggle(
                                NSLocalizedString("Line Numbers", comment: ""),
                                isOn: $editorOptions.value.lineNumbersEnabled
                            )

                            Toggle(
                                "Keyboard Toolbar",
                                isOn: $editorOptions.value.toolBarEnabled
                            ).onChange(
                                of: editorOptions.value.toolBarEnabled
                            ) { value in
                                NotificationCenter.default.post(
                                    name: Notification.Name("toolbarSettingChanged"), object: nil,
                                    userInfo: ["enabled": value])
                            }

                            Toggle("Always Open In New Tab", isOn: self.$alwaysOpenInNewTab)

                            Toggle(
                                NSLocalizedString("Smooth Scrolling", comment: ""),
                                isOn: $editorOptions.value._smoothScrollingEnabled
                            )
                        }

                        Group {
                            Picker(
                                NSLocalizedString("Text Wrap", comment: ""),
                                selection: $editorOptions.value.wordWrap
                            ) {
                                ForEach(WordWrapOption.allCases, id: \.self) {
                                    Text(verbatim: "\($0)")
                                }
                            }

                            Picker(
                                selection: $editorOptions.value.renderWhiteSpaces,
                                label: Text("Render Whitespace")
                            ) {
                                ForEach(RenderWhiteSpaceMode.allCases, id: \.self) {
                                    Text(verbatim: "\($0)")
                                }
                            }
                        }
                    }

                    Section(
                        content: {
                            Toggle("settings.runestone.editor", isOn: $runeStoneEditorEnabled)
                        }, header: { Text("settings.runestone.editor") },
                        footer: { Text("settings.runestone.editor.notes") })

                    Section(header: Text("TERMINAL")) {
                        Toggle(
                            "Keyboard Toolbar",
                            isOn: $terminalToolBarEnabled)
                        Toggle("Show Command in Terminal", isOn: $compilerShowPath)
                    }

                    Section(header: Text(NSLocalizedString("About", comment: ""))) {

                        NavigationLink(
                            destination: SimpleMarkDownView(
                                text: NSLocalizedString("Changelog.message", comment: ""))
                        ) {
                            Text(NSLocalizedString("Release Notes", comment: ""))
                        }

                        Button(action: {
                            showsEraseAlert.toggle()
                        }) {
                            Text(NSLocalizedString("Erase all settings", comment: ""))
                                .foregroundColor(
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
                                    "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
                            )!
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
                                (Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                                    as? String
                                    ?? "0.0") + " Build "
                                    + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String
                                        ?? "0")
                            )
                        }

                        Text("Code App by thebaselab").font(.footnote).foregroundColor(.gray)
                            .onTapGesture(
                                count: 2,
                                perform: {
                                    showReceiptInformation = true
                                })
                    }

                }
                .listRowBackground(Color.init(id: "list.inactiveSelectionBackground"))
            }
            .navigationBarTitle("Settings", displayMode: .inline)
            .navigationBarItems(
                trailing:
                    Button(NSLocalizedString("Done", comment: "")) {
                        self.presentationMode.wrappedValue.dismiss()
                    }
            )
            .configureToolbarBackground()
            .preferredColorScheme(themeManager.colorSchemePreference)
        }
    }
}

extension View {
    @ViewBuilder
    func configureToolbarBackground() -> some View {
        if #available(iOS 16.4, *) {
            self
                .toolbarBackground(
                    Color.init(id: "editor.background"), for: .navigationBar
                )
        } else {
            self
        }
    }
}
