//
//  editorTab.swift
//  Code
//
//  Created by Ken Chung on 16/5/2021.
//

import SwiftUI

struct editorTab: View {
    
    @State var currentEditor: EditorInstance
    
    var isActive: Bool
    var index: Int
    var onOpenEditor: () -> Void
    var onCloseEditor: () -> Void
    var onSaveEditor: () -> Void
    
    static private func keyForInt(int: Int) -> KeyEquivalent {
        if int < 10{
            return KeyEquivalent.init(String(int).first!)
        }
        return KeyEquivalent.init("0")
    }
    
    var body: some View {
        if isActive {
            HStack(){
                fileIcon(url: currentEditor.url, iconSize: 14, type: currentEditor.type)
                Button(action: {}){
                    Group{
                        Text(editorDisplayName(editor: currentEditor))
                        if currentEditor.isDeleted {
                            Text("(deleted)").italic()
                        }
                    }
                        .lineLimit(1)
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(Color.init(id: "tab.activeForeground"))
                }.keyboardShortcut(editorTab.keyForInt(int: index+1), modifiers: .command)
                
                
                if currentEditor.currentVersionId == currentEditor.lastSavedVersionId{
                    Image(systemName: "xmark").font(.system(size:10)).foregroundColor(Color.init(id: "tab.activeForeground"))
                        .padding(.trailing, 2).frame(width: 15, height: 15)
                        .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .hoverEffect(.highlight)
                        .onTapGesture{
                            onCloseEditor()
                        }
                }else{
                    Image(systemName: "circle.fill").font(.system(size:8)).foregroundColor(.gray).padding(.trailing, 2).onTapGesture {
                        onCloseEditor()
                    }
                }
                
            }.frame(height: 40).padding(.leading, 15).padding(.trailing, 15).background(Color.init(id: "tab.activeBackground")).cornerRadius(10, corners: [.topLeft, .topRight])
        }else{
            Button(action: {onOpenEditor()}){
                HStack(){
                    fileIcon(url: currentEditor.url, iconSize: 14, type: currentEditor.type)
                    Text(editorDisplayName(editor: currentEditor)).lineLimit(1).font(.system(size: 14, weight: .light)).foregroundColor(Color.init(id: "tab.inactiveForeground"))
                    if currentEditor.currentVersionId != currentEditor.lastSavedVersionId {
                        Image(systemName: "circle.fill").font(.system(size:8)).foregroundColor(Color.init(id: "tab.inactiveForeground")).padding(.trailing, 2).onTapGesture {
                            onCloseEditor()
                        }
                    }
                }
            }.keyboardShortcut(editorTab.keyForInt(int: index+1), modifiers: .command)
            .frame(height: 40).padding(.leading, 15).padding(.trailing, 15)
            
        }
    }
}
