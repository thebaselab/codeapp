//
//  HierarchyList.swift
//  Code App
//
//  Created by Ken Chung on 31/1/2021.
//

import SwiftUI

public struct HierarchyList<Data, RowContent>: View
where Data: RandomAccessCollection, Data.Element: Identifiable, RowContent: View {
    private let recursiveView: RecursiveView<Data, RowContent>

    public init(
        data: Data, children: KeyPath<Data.Element, Data?>,
        expandStates: Binding<[AnyHashable: Bool]>,
        rowContent: @escaping (Data.Element) -> RowContent,
        onDisclose: @escaping (AnyHashable) -> Void
    ) {
        self.recursiveView = RecursiveView(
            data: data, children: children, rowContent: rowContent, expandStates: expandStates,
            onDisclose: onDisclose)
    }

    public var body: some View {
        recursiveView
    }
}

private struct RecursiveView<Data, RowContent>: View
where Data: RandomAccessCollection, Data.Element: Identifiable, RowContent: View {
    let data: Data
    let children: KeyPath<Data.Element, Data?>
    let rowContent: (Data.Element) -> RowContent
    @Binding var expandStates: [AnyHashable: Bool]

    var onDisclose: (AnyHashable) -> Void

    var body: some View {
        ForEach(data) { child in
            if let subChildren = child[keyPath: children] {
                FSDisclosureGroup(
                    expandStates: $expandStates, id: child.id,
                    content: {
                        RecursiveView(
                            data: subChildren, children: children, rowContent: rowContent,
                            expandStates: $expandStates, onDisclose: onDisclose)
                    },
                    label: {
                        rowContent(child)
                    }, onDisclose: onDisclose
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                rowContent(child)
            }
        }
    }
}

struct FSDisclosureGroup<Label, Content>: View where Label: View, Content: View {
    @Binding var expandStates: [AnyHashable: Bool]
    var id: AnyHashable
    var content: () -> Content
    var label: () -> Label
    var onDisclose: (AnyHashable) -> Void

    init(
        expandStates: Binding<[AnyHashable: Bool]>, id: AnyHashable,
        content: @escaping () -> Content, label: @escaping () -> Label,
        onDisclose: @escaping (AnyHashable) -> Void
    ) {
        self._expandStates = expandStates
        self.id = id
        self.content = content
        self.label = label
        self.onDisclose = onDisclose
    }

    private func binding(for key: AnyHashable) -> Binding<Bool> {
        return .init(
            get: { self.expandStates[key, default: false] },
            set: {
                if $0 {
                    onDisclose(id)
                }
                self.expandStates[key] = $0
            })
    }

    @ViewBuilder
    var body: some View {
        DisclosureGroup(isExpanded: binding(for: id), content: content, label: label)
    }

}
