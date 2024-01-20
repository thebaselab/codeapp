//
//  FileTreeViewController.swift
//  FileTreePlayground
//
//  Created by Ken Chung on 16/01/2024.
//

import SwiftUI
import UIKit

class FileTreeViewController<DataElement, Data>: UIViewController, FileTreeViewDataSource
where Data: RandomAccessCollection, Data.Element: Identifiable, Data.Element == DataElement {

    public internal(set) var data: DataElement
    public internal(set) var headerText: String? = nil
    private var childrenPath: KeyPath<DataElement, Data?>

    // Bi-directional map
    struct UUIDMapping {
        var UUIDToDataElementID: [UUID: DataElement.ID]
        var DataElementIDToUUID: [DataElement.ID: UUID]
        var DataElementIDToDataElement: [DataElement.ID: DataElement]
    }

    private var uuidMapping: UUIDMapping

    init(data: DataElement, children: KeyPath<DataElement, Data?>) {
        self.data = data
        self.childrenPath = children
        self.uuidMapping = FileTreeViewController.buildUUIDMapping(
            data: data, childrenPath: children, existingMapping: nil)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let fileTreeView = FileTreeView()

    var onSelect: ((DataElement) -> Void)? = nil
    var onMove: ((DataElement, DataElement) -> Void)? = nil
    var onContextMenu: ((DataElement) -> UIMenu?)? = nil
    var content: ((DataElement) -> FileTreeViewCell)? = nil
    var onExpand: ((DataElement) -> Void)? = nil
    var onContract: ((DataElement) -> Void)? = nil
    var itemProvider: ((DataElement) -> NSItemProvider?)? = nil

    private var idToScrollToOnAppear: DataElement.ID? = nil

    public func setData(data: DataElement) {
        self.data = data
        self.uuidMapping = FileTreeViewController.buildUUIDMapping(
            data: data, childrenPath: childrenPath, existingMapping: uuidMapping)
        fileTreeView.reloadData()
    }

    public func setHeaderText(text: String) {
        self.headerText = text
        fileTreeView.reloadSectionHeader()
    }

    public func expandCells(cells: [DataElement.ID]) {
        fileTreeView.expandCells(cells: cells.compactMap { uuidMapping.DataElementIDToUUID[$0] })
    }

    public func contractCells(cells: [DataElement.ID]) {
        fileTreeView.contractCells(cells: cells.compactMap { uuidMapping.DataElementIDToUUID[$0] })
    }

    public func reloadCells(cells: [DataElement.ID]) {
        fileTreeView.reloadCells(cells: cells.compactMap { uuidMapping.DataElementIDToUUID[$0] })
    }

    public func scrollToCell(
        cell: DataElement.ID, scrollPosition: UITableView.ScrollPosition, animated: Bool
    ) {
        if self.viewIfLoaded?.window == nil {
            idToScrollToOnAppear = cell
            return
        }
        guard let id = uuidMapping.DataElementIDToUUID[cell] else { return }
        fileTreeView.scrollToCell(cell: id, scrollPosition: scrollPosition, animated: animated)
    }

    private static func buildUUIDMapping(
        data: DataElement, childrenPath: KeyPath<DataElement, Data?>, existingMapping: UUIDMapping?
    ) -> UUIDMapping {
        let UUIDToDataElementID = FileTreeViewController.buildUUIDToDataElementIDMapping(
            data: data, childrenPath: childrenPath, existingMapping: existingMapping)
        let dataElementIDToUUID = FileTreeViewController.inverseUUIDToDataElementIDMapping(
            mapping: UUIDToDataElementID)
        let dataElementIDToDataElement =
            FileTreeViewController.buildDataElementIDToDataElementMapping(
                data: data, childrenPath: childrenPath)
        return UUIDMapping(
            UUIDToDataElementID: UUIDToDataElementID, DataElementIDToUUID: dataElementIDToUUID,
            DataElementIDToDataElement: dataElementIDToDataElement)
    }

    private static func buildDataElementIDToDataElementMapping(
        data: DataElement, childrenPath: KeyPath<DataElement, Data?>
    ) -> [DataElement.ID: DataElement] {
        var result = [DataElement.ID: DataElement]()
        result[data.id] = data

        guard let children = data[keyPath: childrenPath] else { return result }
        for child in children {
            result.merge(
                buildDataElementIDToDataElementMapping(
                    data: child, childrenPath: childrenPath)
            ) { first, _ in first }
        }
        return result
    }

    private static func inverseUUIDToDataElementIDMapping(mapping: [UUID: DataElement.ID])
        -> [DataElement.ID: UUID]
    {
        var result = [DataElement.ID: UUID]()
        for (uuid, id) in mapping {
            result[id] = uuid
        }
        return result
    }

    private static func buildUUIDToDataElementIDMapping(
        data: DataElement, childrenPath: KeyPath<DataElement, Data?>, existingMapping: UUIDMapping?
    ) -> [UUID: DataElement.ID] {
        var result = [UUID: DataElement.ID]()
        if let existingUUID = existingMapping?.DataElementIDToUUID[data.id] {
            result[existingUUID] = data.id
        } else {
            result[UUID()] = data.id
        }

        guard let children = data[keyPath: childrenPath] else { return result }
        for child in children {
            result.merge(
                buildUUIDToDataElementIDMapping(
                    data: child, childrenPath: childrenPath, existingMapping: existingMapping)
            ) { first, _ in first }
        }
        return result
    }

    // This is too slow!
    private func dataForElementID(id: DataElement.ID, at: DataElement) -> DataElement? {
        return uuidMapping.DataElementIDToDataElement[id]
    }

    private func dataForUUID(uuid: UUID, at: DataElement) -> DataElement? {
        let elementId = uuidMapping.UUIDToDataElementID[uuid]!
        return dataForElementID(id: elementId, at: at)
    }

    func fileTreeView(_ fileTreeView: FileTreeView, childrenOfItem: UUID) -> [UUID]? {
        guard let children = dataForUUID(uuid: childrenOfItem, at: data)?[keyPath: childrenPath]
        else { return nil }
        return children.map { uuidMapping.DataElementIDToUUID[$0.id]! }
    }

    func fileTreeView(_ fileTreeView: FileTreeView, hasChildrenForItem: UUID) -> Bool {
        return dataForUUID(uuid: hasChildrenForItem, at: data)?[keyPath: childrenPath] != nil
    }

    func fileTreeView(_ fileTreeView: FileTreeView, cellForItem: UUID) -> FileTreeViewCell {
        guard let data = dataForUUID(uuid: cellForItem, at: self.data),
            let content
        else {
            return FileTreeViewCell(
                configuration: UIHostingConfiguration { EmptyView() },
                isHighlighted: false
            )
        }
        return content(data)
    }

    func fileTreeView(_ fileTreeView: FileTreeView, itemProviderForItem: UUID) -> NSItemProvider? {
        guard let data = dataForUUID(uuid: itemProviderForItem, at: self.data) else { return nil }
        return itemProvider?(data)
    }

    func rootItem(_ fileTreeView: FileTreeView) -> UUID {
        return uuidMapping.DataElementIDToUUID[data.id]!
    }

    func headerTitle(_ fileTreeView: FileTreeView) -> String? {
        return headerText
    }

    override func loadView() {
        self.view = fileTreeView
    }

    override func viewWillAppear(_ animated: Bool) {
        fileTreeView.delegate = self
        fileTreeView.dataSource = self
    }

    override func viewDidAppear(_ animated: Bool) {
        if let idToScrollToOnAppear {
            self.scrollToCell(cell: idToScrollToOnAppear, scrollPosition: .middle, animated: false)
        }
    }

}

extension FileTreeViewController: FileTreeViewDelegate {
    func fileTreeView(_ fileTreeView: FileTreeView, selectCell at: UUID) {
        guard let data = dataForUUID(uuid: at, at: data) else { return }
        onSelect?(data)
    }

    func fileTreeView(_ fileTreeView: FileTreeView, moveCell from: UUID, to: UUID) {
        guard let fromData = dataForUUID(uuid: from, at: data),
            let toData = dataForUUID(uuid: to, at: data)
        else { return }
        onMove?(fromData, toData)
    }

    func fileTreeView(_ fileTreeView: FileTreeView, contextMenuForItem: UUID)
        -> UIMenu?
    {
        guard let data = dataForUUID(uuid: contextMenuForItem, at: data) else { return nil }
        return onContextMenu?(data)
    }

    func fileTreeView(_ fileTreeView: FileTreeView, didExpandCellAt item: UUID) {
        guard let data = dataForUUID(uuid: item, at: data) else { return }
        onExpand?(data)
    }

    func fileTreeView(_ fileTreeView: FileTreeView, didContractCellAt item: UUID) {
        guard let data = dataForUUID(uuid: item, at: data) else { return }
        onContract?(data)
    }
}
