//
//  shortcutPreview.swift
//  Code
//
//  Created by Ken Chung on 23/1/2022.
//

import SwiftUI
import GameController

struct characterBlock: View{
    
    @State var key: String
    
    var body: some View {
        HStack{
            if(["shift", "command", "arrow.up", "arrow.down", "arrow.left", "arrow.right", "delete.forward", "delete.backward", "option", "capslock", "control"].contains(key)){
                Image(systemName: key)
            }else{
                Text(key)
            }
        }
        .font(.system(size: 14, weight: .regular, design: .default))
        .padding(4)
        .background(Color.init(id: "sideBar.background"))
        .cornerRadius(4)
    }
}

struct shortcutPreview: View {
    
    @Environment(\.scenePhase) var scenePhase
    @State var keysDown: Set<GCKeyCode>
    @State var started = false
    @State var displayedKeys: [displayedKey] = []
    @Binding var storedShortcuts: [String:[GCKeyCode]]
    let shortcutID: String
    let onUpdate: () -> ()
    
    init(shortcutID: String, existingShortcuts: Binding<[String:[GCKeyCode]]>, onUpdate: @escaping () -> ()){
        self.shortcutID = shortcutID
        self.onUpdate = onUpdate
        _storedShortcuts = existingShortcuts
        
        let existingKeys = existingShortcuts.wrappedValue[shortcutID]
        
        _keysDown = State(initialValue: Set(existingKeys ?? []))
        _displayedKeys = State(initialValue: keysDown.compactMap{shortcutsMapping[$0]?.1}.sorted{
            if($0.count != $1.count){
                return $0.count > $1.count
            }else{
                return $0 < $1
            }
        }.map{displayedKey(value: $0)})
    }
    
    struct displayedKey: Identifiable {
        var id = UUID()
        var value: String
    }
    
    var body: some View {
        if(!started){
            Text("External keyboard not detected.")
                .foregroundColor(.gray)
        }
        VStack{
            if(keysDown.isEmpty && started){
                Text("No shortcut set. Enter the new keystrokes on your keyboard.")
                    .foregroundColor(.gray)
            }
            
            HStack{
                ForEach(displayedKeys){key in
                    characterBlock(key: key.value)
                }
            }
            
            if(!keysDown.isEmpty && started){
                Button("Reset"){
                    keysDown.removeAll()
                    displayedKeys.removeAll()
                }
            }
        }
        .onChange(of: keysDown){ newValue in
            displayedKeys = keysDown.compactMap{shortcutsMapping[$0]?.1}.sorted{
                if($0.count != $1.count){
                    return $0.count > $1.count
                }else{
                    return $0 < $1
                }
            }.map{displayedKey(value: $0)}
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase != .active {
                keysDown.removeAll()
            }
        }.onAppear{
            if let keyboard = GCKeyboard.coalesced?.keyboardInput {
                started = true
                keyboard.keyChangedHandler = { (keyboard, key, keyCode, pressed) in
                    if pressed {
                        keysDown.insert(keyCode)
                    }
                }
            }
        }.onDisappear{
            // Save the shortcuts
            let userDefaultskey = "thebaselab.custom.keyboard.shortcuts"
            
            if var result = UserDefaults.standard.value(forKey: userDefaultskey) as? [String:[GCKeyCode]]{
                if keysDown.isEmpty {
                    result.removeValue(forKey: shortcutID)
                    storedShortcuts.removeValue(forKey: shortcutID)
                }else{
                    result[shortcutID] = Array(keysDown)
                    storedShortcuts[shortcutID] = Array(keysDown)
                }
                UserDefaults.standard.set(result, forKey: userDefaultskey)
                onUpdate()
            }else{
                if keysDown.isEmpty {
                    return
                }
                let newDictionary: [String:[GCKeyCode]] = [shortcutID:Array(keysDown)]
                storedShortcuts[shortcutID] = Array(keysDown)
                UserDefaults.standard.set(newDictionary, forKey: userDefaultskey)
            }
        }
    }
}
