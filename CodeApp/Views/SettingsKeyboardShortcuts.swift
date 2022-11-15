//
//  customShortcut.swift
//  Code
//
//  Created by Ken Chung on 23/1/2022.
//

import GameController
import SwiftUI

struct SettingsKeyboardShortcuts: View {

    @EnvironmentObject var App: MainApp
    @State var filter: String = ""
    @State var storedShortcuts: [String: [GCKeyCode]] = [:]

    init() {
        if let result = UserDefaults.standard.value(forKey: "thebaselab.custom.keyboard.shortcuts")
            as? [String: [GCKeyCode]]
        {
            _storedShortcuts = State(initialValue: result)
        }
        // This must be called twice for it to work for some reason.
        let _ = GCKeyboard.coalesced?.keyboardInput
    }

    var body: some View {
        VStack {
            SearchBar(text: $filter, searchAction: nil, placeholder: "Search", cornerRadius: 6)
                .padding(.horizontal)
            DescriptionText(
                "Note: Keyboard shortcuts that clash with existing shortcuts will not apply.")
            Form {
                Section("Actions") {
                    List(
                        App.editorShortcuts.filter {
                            filter.isEmpty || $0.label.lowercased().contains(filter.lowercased())
                        }.sorted(by: { a, b in
                            if let _ = storedShortcuts[a.id] {
                                return true
                            } else {
                                return false
                            }
                        })
                    ) { shortcut in
                        NavigationLink(
                            destination: ShortcutPreview(
                                shortcutID: shortcut.id, existingShortcuts: $storedShortcuts,
                                onUpdate: {
                                    App.monacoInstance.applyCustomShortcuts()
                                }),
                            label: {
                                HStack {
                                    Text(shortcut.label)
                                    Spacer()
                                    if let keycodes = storedShortcuts[shortcut.id] {
                                        HStack {
                                            ForEach(
                                                keycodes.compactMap { shortcutsMapping[$0]?.1 }
                                                    .sorted {
                                                        if $0.count != $1.count {
                                                            return $0.count > $1.count
                                                        } else {
                                                            return $0 < $1
                                                        }
                                                    }.map {
                                                        ShortcutPreview.displayedKey(value: $0)
                                                    }
                                            ) { key in
                                                CharacterBlock(key: key.value)
                                            }
                                        }
                                    } else {
                                        Text("Not set")
                                            .foregroundColor(.gray)
                                    }
                                }
                            })
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
        }.onAppear {
            if let result = UserDefaults.standard.value(
                forKey: "thebaselab.custom.keyboard.shortcuts") as? [String: [GCKeyCode]]
            {
                storedShortcuts = result
            }
        }
    }
}

private struct ShortcutPreview: View {

    @Environment(\.scenePhase) var scenePhase
    @State var keysDown: Set<GCKeyCode>
    @State var started = false
    @State var displayedKeys: [displayedKey] = []
    @Binding var storedShortcuts: [String: [GCKeyCode]]
    let shortcutID: String
    let onUpdate: () -> Void

    init(
        shortcutID: String, existingShortcuts: Binding<[String: [GCKeyCode]]>,
        onUpdate: @escaping () -> Void
    ) {
        self.shortcutID = shortcutID
        self.onUpdate = onUpdate
        _storedShortcuts = existingShortcuts

        let existingKeys = existingShortcuts.wrappedValue[shortcutID]

        _keysDown = State(initialValue: Set(existingKeys ?? []))
        _displayedKeys = State(
            initialValue: keysDown.compactMap { shortcutsMapping[$0]?.1 }.sorted {
                if $0.count != $1.count {
                    return $0.count > $1.count
                } else {
                    return $0 < $1
                }
            }.map { displayedKey(value: $0) })
    }

    struct displayedKey: Identifiable {
        var id = UUID()
        var value: String
    }

    var keysAreValid: Bool {
        return
            (keysDown.contains(.leftShift) || keysDown.contains(.rightShift)
            || keysDown.contains(.leftAlt) || keysDown.contains(.rightAlt)
            || keysDown.contains(.leftControl) || keysDown.contains(.rightControl)
            || keysDown.contains(.leftGUI) || keysDown.contains(.rightGUI))
    }

    var body: some View {
        if !started {
            Text("External keyboard not detected.")
                .foregroundColor(.gray)
        }
        VStack {
            if keysDown.isEmpty && started {
                Text("No shortcut set. Enter the new keystrokes on your keyboard.")
                    .foregroundColor(.gray)
            }

            HStack {
                ForEach(displayedKeys) { key in
                    CharacterBlock(key: key.value)
                }
            }

            if !keysDown.isEmpty && started {
                if !(keysAreValid) {
                    Text("Keystorkes are not valid. At least one modifier key is required.")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.vertical)
                }
                Button("Reset") {
                    keysDown.removeAll()
                    displayedKeys.removeAll()
                }
            }
        }
        .onChange(of: keysDown) { newValue in
            displayedKeys = keysDown.compactMap { shortcutsMapping[$0]?.1 }.sorted {
                if $0.count != $1.count {
                    return $0.count > $1.count
                } else {
                    return $0 < $1
                }
            }.map { displayedKey(value: $0) }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase != .active {
                keysDown.removeAll()
            }
        }.onAppear {
            if let keyboard = GCKeyboard.coalesced?.keyboardInput {
                started = true
                keyboard.keyChangedHandler = { (keyboard, key, keyCode, pressed) in
                    if pressed {
                        keysDown.insert(keyCode)
                    }
                }
            }
        }.onDisappear {
            guard keysAreValid || keysDown.isEmpty else {
                return
            }
            // Save the shortcuts
            let userDefaultskey = "thebaselab.custom.keyboard.shortcuts"

            if var result = UserDefaults.standard.value(forKey: userDefaultskey)
                as? [String: [GCKeyCode]]
            {
                if keysDown.isEmpty {
                    result.removeValue(forKey: shortcutID)
                    storedShortcuts.removeValue(forKey: shortcutID)
                } else {
                    result[shortcutID] = Array(keysDown)
                    storedShortcuts[shortcutID] = Array(keysDown)
                }
                UserDefaults.standard.set(result, forKey: userDefaultskey)
                onUpdate()
            } else {
                if keysDown.isEmpty {
                    return
                }
                let newDictionary: [String: [GCKeyCode]] = [shortcutID: Array(keysDown)]
                storedShortcuts[shortcutID] = Array(keysDown)
                UserDefaults.standard.set(newDictionary, forKey: userDefaultskey)
            }
        }
    }
}

private struct CharacterBlock: View {

    @State var key: String

    var body: some View {
        HStack {
            if [
                "shift", "command", "arrow.up", "arrow.down", "arrow.left", "arrow.right",
                "delete.forward", "delete.backward", "option", "capslock", "control",
            ].contains(key) {
                Image(systemName: key)
            } else {
                Text(key)
            }
        }
        .font(.system(size: 14, weight: .regular, design: .default))
        .padding(4)
        .background(Color.init(id: "sideBar.background"))
        .cornerRadius(4)
    }
}
