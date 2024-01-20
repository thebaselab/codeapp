//
//  TableView.swift
//  FileTreePlayground
//
//  Created by Ken Chung on 16/01/2024.
//

import SwiftUI
import UIKit

struct TableViewCellState<DataElement: Identifiable>: Equatable {
    var highlightedCells: Set<DataElement.ID>
    var cellDecorations: [DataElement.ID: CellDecoration]
}

struct TableView<DataElement, Data, RowContent>: UIViewControllerRepresentable
where
    Data: RandomAccessCollection, Data.Element: Identifiable, Data.Element: Equatable,
    Data.Element == DataElement, RowContent: UIContentConfiguration
{
    @EnvironmentObject var App: MainApp  // Remove this if possible
    @EnvironmentObject var themeManager: ThemeManager

    var root: DataElement
    var children: KeyPath<DataElement, Data?>
    var onSelect: ((DataElement) -> Void)? = nil
    var onMove: ((DataElement, DataElement) -> Void)? = nil
    var onContextMenu: ((DataElement) -> UIMenu?)? = nil
    var onExpand: ((DataElement) -> Void)? = nil
    var onDrag: ((DataElement) -> NSItemProvider?)? = nil
    var header: String? = nil
    @ViewBuilder var content: (DataElement) -> RowContent
    @Binding var expandedCells: Set<DataElement.ID>
    var cellState: TableViewCellState<DataElement>
    @State var cellToScrollTo: DataElement.ID? = nil

    private func updateExpandedCells(
        in controller: FileTreeViewController<DataElement, Data>, with context: Context
    ) {
        let cellsToExpand = expandedCells.subtracting(context.coordinator.lastExpandedCells)
        let cellsToContract = context.coordinator.lastExpandedCells.subtracting(expandedCells)
        controller.expandCells(cells: Array(cellsToExpand))
        controller.contractCells(cells: Array(cellsToContract))
        context.coordinator.lastExpandedCells = expandedCells
    }

    private func updateCellStates(
        in controller: FileTreeViewController<DataElement, Data>, with context: Context
    ) {
        if context.coordinator.lastCellState == cellState { return }
        context.coordinator.cellState = cellState
        let cellsToHighlight = cellState.highlightedCells.subtracting(
            context.coordinator.lastCellState.highlightedCells)
        let cellsToDehighlight = context.coordinator.lastCellState.highlightedCells.subtracting(
            cellState.highlightedCells)
        let cellsWithDecorationToReload = Set(cellState.cellDecorations.keys).union(
            Set(context.coordinator.lastCellState.cellDecorations.keys))
        controller.reloadCells(
            cells: Array(cellsToHighlight) + Array(cellsToDehighlight)
                + Array(cellsWithDecorationToReload))
        context.coordinator.lastCellState = cellState
    }

    init(
        _ root: DataElement, children: KeyPath<DataElement, Data?>,
        cellState: TableViewCellState<DataElement>, expandedCells: Binding<Set<DataElement.ID>>,
        content: @escaping (DataElement) -> RowContent
    ) {
        self.root = root
        self.children = children
        self.content = content
        self.cellState = cellState
        self._expandedCells = expandedCells
    }

    class Coordinator {
        var lastExpandedCells = Set<DataElement.ID>()
        var lastTheme: Theme? = nil
        var cellState: TableViewCellState<DataElement>
        var lastCellState = TableViewCellState<DataElement>(
            highlightedCells: Set<DataElement.ID>(), cellDecorations: [:])
        weak var controller: FileTreeViewController<DataElement, Data>?
        private var sceneIdentifier: UUID
        @Binding var cellToScrollTo: DataElement.ID?

        @objc func notificationHandler(notification: Notification) {
            guard
                let target = notification.userInfo?["target"] as? DataElement.ID,
                let notificationSceneIdentifier = notification.userInfo?["sceneIdentifier"]
                    as? UUID,
                sceneIdentifier == notificationSceneIdentifier
            else {
                return
            }
            cellToScrollTo = target
        }

        init(
            cellState: TableViewCellState<DataElement>, sceneIdentifier: UUID,
            cellToScrollTo: Binding<DataElement.ID?>
        ) {
            self.cellState = cellState
            self.sceneIdentifier = sceneIdentifier
            self._cellToScrollTo = cellToScrollTo
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(
            cellState: cellState, sceneIdentifier: App.sceneIdentifier,
            cellToScrollTo: $cellToScrollTo)
    }

    func makeUIViewController(context: Context) -> FileTreeViewController<DataElement, Data> {
        let controller = FileTreeViewController(data: root, children: children)
        controller.onSelect = {
            onSelect?($0)
        }
        controller.onMove = {
            onMove?($0, $1)
        }
        controller.content = {
            FileTreeViewCell(
                configuration: content($0),
                isHighlighted: context.coordinator.cellState.highlightedCells.contains($0.id),
                decoration: context.coordinator.cellState.cellDecorations[$0.id]
            )
        }
        controller.onContextMenu = {
            onContextMenu?($0)
        }
        controller.onExpand = {
            expandedCells.insert($0.id)
            context.coordinator.lastExpandedCells = expandedCells
            onExpand?($0)
        }
        controller.onContract = {
            expandedCells.remove($0.id)
            context.coordinator.lastExpandedCells = expandedCells
        }
        controller.itemProvider = {
            onDrag?($0)
        }
        DispatchQueue.main.async {
            updateExpandedCells(in: controller, with: context)
        }
        context.coordinator.lastTheme = themeManager.currentTheme
        // This is ugly. How do we implement something like ScrollViewReader?
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(context.coordinator.notificationHandler(notification:)),
            name: Notification.Name("explorer.scrollto"), object: nil)
        return controller
    }

    func updateUIViewController(
        _ uiViewController: FileTreeViewController<DataElement, Data>, context: Context
    ) {
        if root != uiViewController.data
            || context.coordinator.lastTheme?.id != themeManager.currentTheme?.id
        {
            uiViewController.setData(data: root)
        }
        if let header, header != uiViewController.headerText {
            uiViewController.setHeaderText(text: header)
        }
        updateExpandedCells(in: uiViewController, with: context)
        updateCellStates(in: uiViewController, with: context)

        if let cellToScrollTo {
            DispatchQueue.main.async { self.cellToScrollTo = nil }
            uiViewController.scrollToCell(
                cell: cellToScrollTo, scrollPosition: .middle, animated: false)
        }
    }
}

extension TableView {
    public func onSelect(_ action: @escaping (DataElement) -> Void) -> TableView {
        var updatedView = self
        updatedView.onSelect = action
        return updatedView
    }

    public func onMove(_ action: @escaping (DataElement, DataElement) -> Void) -> TableView {
        var updatedView = self
        updatedView.onMove = action
        return updatedView
    }

    public func onContextMenu(_ builder: @escaping (DataElement) -> UIMenu?)
        -> TableView
    {
        var updatedView = self
        updatedView.onContextMenu = builder
        return updatedView
    }

    public func onExpand(_ action: @escaping (DataElement) -> Void) -> TableView {
        var updatedView = self
        updatedView.onExpand = action
        return updatedView
    }

    public func headerText(_ text: String) -> TableView {
        var updatedView = self
        updatedView.header = text
        return updatedView
    }

    public func onTabelViewCellDrag(_ action: @escaping (DataElement) -> NSItemProvider?)
        -> TableView
    {
        var updatedView = self
        updatedView.onDrag = action
        return updatedView
    }

}
