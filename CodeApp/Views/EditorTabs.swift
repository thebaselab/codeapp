//
//  tabs.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI
import UniformTypeIdentifiers

struct CompactEditorTabs: View {
    @EnvironmentObject var App: MainApp

    var body: some View {
        Menu {
            if let activeEditor = App.activeEditor {
                Section(
                    (activeEditor as? EditorInstanceWithURL)?.pathAfterUUID ?? activeEditor.title
                ) {
                    Button(role: .destructive) {
                        App.closeEditor(editor: activeEditor)
                    } label: {
                        Label("Close Editor", systemImage: "xmark")
                    }
                }
            }

            Section("Open Editors") {
                ForEach(App.editors) { editor in
                    Button {
                        App.setActiveEditor(editor: editor)
                    } label: {
                        FileIcon(url: editor.title, iconSize: 12)
                        Text(editor.title)
                    }
                }
            }
        } label: {
            HStack {
                Text(App.activeEditor?.title ?? "")
                    .bold()
                    .lineLimit(1)
                    .foregroundColor(Color(id: "activityBar.foreground"))

                if App.editors.count > 0 {
                    Image(systemName: "chevron.down.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
        .id(UUID())

    }
}

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
                ForEach(App.editors) { currentEditor in
                    EditorTab(
                        currentEditor: currentEditor,
                        isActive: (App.activeEditor == currentEditor),
                        onOpenEditor: {
                            App.setActiveEditor(editor: currentEditor)
                        },
                        onCloseEditor: {
                            App.closeEditor(editor: currentEditor)
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
