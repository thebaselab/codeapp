//
//  tabs.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI
import UniformTypeIdentifiers

struct EditorTabs: View {
    @EnvironmentObject var App: MainApp

    @State private var dragging: EditorInstance?

    struct DragRelocateDelegate: DropDelegate {
        let item: EditorInstance
        @Binding var listData: [EditorInstance]
        @Binding var current: EditorInstance?

        func dropEntered(info: DropInfo) {
            if item != current, current != nil {
                let from = listData.firstIndex(of: current!)!
                let to = listData.firstIndex(of: item)!
                if listData[to].id != current!.id {
                    withAnimation {
                        listData.move(
                            fromOffsets: IndexSet(integer: from),
                            toOffset: to > from ? to + 1 : to)
                    }
                }
            }
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            return DropProposal(operation: .move)
        }

        func performDrop(info: DropInfo) -> Bool {
            self.current = nil
            return true
        }
    }

    private func keyForInt(int: Int) -> KeyEquivalent {
        if int < 10 {
            return KeyEquivalent.init(String(int).first!)
        }
        return KeyEquivalent.init("0")
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(App.editors.enumerated()), id: \.element) { i, currentEditor in
                    EditorTab(
                        currentEditor: currentEditor, isActive: (App.activeEditor == currentEditor),
                        index: i,
                        onOpenEditor: {
                            App.setActiveEditor(editor: currentEditor)
                        },
                        onCloseEditor: {
                            App.closeEditor(editor: currentEditor)
                        },
                        onSaveEditor: {
                            if let currentTextEditor = currentEditor as? TextEditorInstance {
                                App.saveTextEditor(editor: currentTextEditor)
                            }
                        }
                    )
                    .onDrag {
                        self.dragging = currentEditor
                        return NSItemProvider(object: currentEditor.id.uuidString as NSString)
                    }
                    .onDrop(
                        of: [UTType.text],
                        delegate: DragRelocateDelegate(
                            item: currentEditor, listData: $App.editors, current: $dragging))
                }
            }
        }
    }
}
