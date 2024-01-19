//
//  TableView.swift
//  FileTreePlayground
//
//  Created by Ken Chung on 16/01/2024.
//

import SwiftUI
import UIKit

// Option 1: Embed these UI states in one Binding variable
struct TableViewCellState<DataElement: Identifiable>: Equatable {
    var highlightedCells: Set<DataElement.ID>
    var cellDecorations: [DataElement.ID: CellDecoration]
}

struct TableView<DataElement, Data, RowContent>: UIViewControllerRepresentable
where
    Data: RandomAccessCollection, Data.Element: Identifiable, Data.Element: Equatable,
    Data.Element == DataElement, RowContent: UIContentConfiguration
{
    var root: DataElement
    var children: KeyPath<DataElement, Data?>
    var onSelect: ((DataElement) -> Void)? = nil
    var onMove: ((DataElement, DataElement) -> Void)? = nil
    var onContextMenu: ((DataElement) -> UIContextMenuConfiguration?)? = nil
    var onExpand: ((DataElement) -> Void)? = nil
    var onDrag: ((DataElement) -> NSItemProvider?)? = nil
    var header: String? = nil
    @ViewBuilder var content: (DataElement) -> RowContent
    @Binding var expandedCells: Set<DataElement.ID>
    var cellState: TableViewCellState<DataElement>

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
        var cellState: TableViewCellState<DataElement>
        var lastCellState = TableViewCellState<DataElement>(
            highlightedCells: Set<DataElement.ID>(), cellDecorations: [:])

        init(cellState: TableViewCellState<DataElement>) {
            self.cellState = cellState
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(cellState: cellState)
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
        return controller
    }

    func updateUIViewController(
        _ uiViewController: FileTreeViewController<DataElement, Data>, context: Context
    ) {
        // TODO: Diff the data
        if root != uiViewController.data { uiViewController.setData(data: root) }
        if let header, header != uiViewController.headerText {
            uiViewController.setHeaderText(text: header)
        }
        updateExpandedCells(in: uiViewController, with: context)
        updateCellStates(in: uiViewController, with: context)
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

    public func onContextMenu(_ builder: @escaping (DataElement) -> UIContextMenuConfiguration?)
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
