//
//  customShortcut.swift
//  Code
//
//  Created by Ken Chung on 23/1/2022.
//

import SwiftUI
import GameController

struct customShortcuts: View {
    
    @EnvironmentObject var App: MainApp
    @State var filter: String = ""
    @State var storedShortcuts: [String:[GCKeyCode]] = [:]
    
    init(){
        if let result = UserDefaults.standard.value(forKey: "thebaselab.custom.keyboard.shortcuts") as? [String:[GCKeyCode]]{
            _storedShortcuts = State(initialValue: result)
        }
        // This must be called twice for it to work for some reason.
        let _ = GCKeyboard.coalesced?.keyboardInput
    }
    
    var body: some View {
        VStack{
            SearchBar(text: $filter, searchAction: nil, placeholder: "Search", cornerRadius: 6)
                .padding(.horizontal)
            Form {
                Section("Actions"){
                    List(App.editorShortcuts.filter{
                        filter.isEmpty || $0.label.lowercased().contains(filter.lowercased())
                    }){ shortcut in
                        NavigationLink(destination: shortcutPreview(shortcutID: shortcut.id, existingShortcuts: $storedShortcuts, onUpdate: {
                            App.monacoInstance.applyCustomShortcuts()
                        }), label: {
                            HStack{
                                Text(shortcut.label)
                                Spacer()
                                if let keycodes = storedShortcuts[shortcut.id] {
                                    HStack{
                                        ForEach(keycodes.compactMap{shortcutsMapping[$0]?.1}.sorted{
                                            if($0.count != $1.count){
                                                return $0.count > $1.count
                                            }else{
                                                return $0 < $1
                                            }
                                        }.map{shortcutPreview.displayedKey(value: $0)}){key in
                                            characterBlock(key: key.value)
                                        }
                                    }
                                }else{
                                    Text("Not set")
                                        .foregroundColor(.gray)
                                }
                            }
                        })
                    }
                }
                
            }
        }.onAppear{
            if let result = UserDefaults.standard.value(forKey: "thebaselab.custom.keyboard.shortcuts") as? [String:[GCKeyCode]]{
                storedShortcuts = result
            }
        }
    }
}
