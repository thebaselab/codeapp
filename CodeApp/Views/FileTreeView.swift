//
//  FileTreeView.swift
//  FileTreePlayground
//
//  Created by Ken Chung on 14/01/2024.
//

import SwiftUI
import UIKit

private var DISCLOSE_ON_HOVER_THRESHOLD = TimeInterval(1)  // 1 second

extension UIView {
    func clip(with view: UIView) {
        self.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        self.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        self.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        self.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
}

extension ClosedRange<Array<TableViewDelegate.CellCache>.Index> {
    var indexPaths: [IndexPath] {
        return self.map { IndexPath(row: $0, section: 0) }
    }
}

class TableViewDelegate: NSObject, UITableViewDataSource {

    public func reloadData(_ tableView: UITableView) {
        guard let fileTreeDataSource, let treeView else { return }
        let rootItem = fileTreeDataSource.rootItem(treeView)
        cachedTable = buildCachedTable(at: rootItem)
        tableView.reloadData()
    }

    public func reloadSectionHeader(_ tableView: UITableView) {
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
    }

    public func reloadCells(_ tableView: UITableView, at: [UUID]) {
        let cellSet = Set(at)
        var indexPaths: [IndexPath] = []
        for i in 0..<cachedTable.count {
            if cellSet.contains(cachedTable[i].id) {
                indexPaths.append(IndexPath(row: i, section: 0))
            }
        }
        tableView.reloadRows(at: indexPaths, with: .none)
    }

    public func scrollToCell(
        _ tableView: UITableView, at: UUID, scrollPosition: UITableView.ScrollPosition,
        animated: Bool
    ) {
        guard let indexPath = indexPathForItem(item: at) else { return }
        tableView.scrollToRow(at: indexPath, at: scrollPosition, animated: animated)
    }

    weak var fileTreeDataSource: FileTreeViewDataSource? {
        didSet {
            guard let fileTreeDataSource, let treeView else { return }
            let rootItem = fileTreeDataSource.rootItem(treeView)
            cachedTable = buildCachedTable(at: rootItem)
        }
    }
    weak var fileTreeDelegate: FileTreeViewDelegate?
    weak var treeView: FileTreeView?

    private var expandStatus = Set<UUID>() {
        didSet {
            guard let fileTreeDataSource, let treeView else { return }
            let rootItem = fileTreeDataSource.rootItem(treeView)
            cachedTable = buildCachedTable(at: rootItem)
        }
    }
    struct CellCache {
        var id: UUID
        var depth: Int
        var hasChildren: Bool
    }
    private var cachedTable: [CellCache] = []

    private var dropDestinationHighlightedCells = Set<UUID>()
    private var lastHoverStartedDate: Date = Date.distantPast
    private var lastHoveredIndexPath: IndexPath? = nil
    private var lastHoveredResult = UITableViewDropProposal(operation: .cancel)
    private var draggedCells = Set<UUID>()

    private func buildCachedTable(at item: UUID, depth: Int = 0) -> [CellCache] {
        guard let fileTreeDataSource, let treeView else { return [] }

        guard let children = fileTreeDataSource.fileTreeView(treeView, childrenOfItem: item) else {
            return []
        }

        var result: [CellCache] = []
        for child in children {
            result.append(
                CellCache(
                    id: child,
                    depth: depth,
                    hasChildren: fileTreeDataSource.fileTreeView(
                        treeView, hasChildrenForItem: child)
                )
            )
            if expandStatus.contains(child) {
                result += buildCachedTable(at: child, depth: depth + 1)
            }
        }
        return result
    }

    private func indexPathForItem(item: UUID) -> IndexPath? {
        guard let index = (cachedTable.firstIndex { $0.id == item }) else {
            return nil
        }
        return IndexPath(item: index, section: 0)
    }

    private func convertIndexPathToItem(indexPath: IndexPath) -> CellCache {
        return cachedTable[indexPath.row]
    }

    private func indexRangeForCellAndItsChildren(cell: UUID) -> ClosedRange<Array<CellCache>.Index>?
    {
        guard let startIndex = (cachedTable.firstIndex { $0.id == cell }) else { return nil }
        let startItem = cachedTable[startIndex]
        let endIndex =
            ((cachedTable[(startIndex + 1)...].firstIndex { $0.depth <= startItem.depth })
                ?? cachedTable.count) - 1
        return startIndex...endIndex
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cachedTable.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        guard let fileTreeDataSource, let treeView else { return cell }

        let item = convertIndexPathToItem(indexPath: indexPath)
        let treeViewCellContentConfiguration = fileTreeDataSource.fileTreeView(
            treeView, cellForItem: item.id)

        cell.indentationLevel = item.depth
        cell.contentConfiguration = treeViewCellContentConfiguration.configuration

        if item.hasChildren {
            let image: UIImage =
                expandStatus.contains(item.id)
                ? UIImage(
                    systemName: "chevron.down",
                    withConfiguration: UIImage.SymbolConfiguration(
                        pointSize: 12, weight: .semibold))!
                : UIImage(
                    systemName: "chevron.right",
                    withConfiguration: UIImage.SymbolConfiguration(
                        pointSize: 12, weight: .semibold))!
            cell.accessoryView = UIImageView(
                image: image.withTintColor(.systemGray, renderingMode: .alwaysOriginal))
        } else {
            if let decoration = treeViewCellContentConfiguration.decoration {
                let label = UILabel()
                label.text = decoration.text
                label.textColor = UIColor(decoration.backgroundColor)
                label.sizeToFit()
                label.font = UIFont.preferredFont(forTextStyle: .subheadline)
                cell.accessoryView = label
            } else {
                cell.accessoryView = nil
            }
        }

        if dropDestinationHighlightedCells.contains(item.id)
            || treeViewCellContentConfiguration.isHighlighted
        {
            var backgroundConfig = UIBackgroundConfiguration.clear()
            backgroundConfig.backgroundColor = UIColor(
                Color.init(id: "list.inactiveSelectionBackground"))
            backgroundConfig.cornerRadius = 10
            if dropDestinationHighlightedCells.contains(item.id) {
                backgroundConfig.cornerRadius = 0
            }
            cell.backgroundConfiguration = backgroundConfig
        }

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let fileTreeDataSource, let treeView else { return nil }
        return fileTreeDataSource.headerTitle(treeView)
    }
}

extension TableViewDelegate: UITableViewDelegate {

    private func expandCell(_ tableView: UITableView, at indexPath: IndexPath) {
        let item = convertIndexPathToItem(indexPath: indexPath)
        expandCell(tableView, at: item.id)
    }

    public func expandCell(_ tableView: UITableView, at itemID: UUID) {
        if expandStatus.contains(itemID) { return }
        expandStatus.insert(itemID)
        guard let range = indexRangeForCellAndItsChildren(cell: itemID) else { return }
        tableView.insertRows(at: Array(range.indexPaths.dropFirst()), with: .none)
        if let firstIndexPath = range.indexPaths.first {
            tableView.reloadRows(at: [firstIndexPath], with: .none)
        }
    }

    private func closeCell(_ tableView: UITableView, at indexPath: IndexPath) {
        let item = convertIndexPathToItem(indexPath: indexPath)
        closeCell(tableView, at: item.id)
    }

    public func closeCell(_ tableView: UITableView, at itemID: UUID) {
        if !expandStatus.contains(itemID) { return }
        guard let range = indexRangeForCellAndItsChildren(cell: itemID) else { return }
        expandStatus.remove(itemID)
        tableView.deleteRows(at: Array(range.indexPaths.dropFirst()), with: .none)
        if let firstIndexPath = range.indexPaths.first {
            tableView.reloadRows(at: [firstIndexPath], with: .none)
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let fileTreeDataSource, let treeView else { return }

        let item = convertIndexPathToItem(indexPath: indexPath)

        fileTreeDelegate?.fileTreeView(treeView, selectCell: item.id)

        if fileTreeDataSource.fileTreeView(treeView, childrenOfItem: item.id) == nil {
            return
        }

        if expandStatus.contains(item.id) {
            closeCell(tableView, at: indexPath)
            fileTreeDelegate?.fileTreeView(treeView, didContractCellAt: item.id)
        } else {
            expandCell(tableView, at: indexPath)
            fileTreeDelegate?.fileTreeView(treeView, didExpandCellAt: item.id)
        }
    }

    func tableView(
        _ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let fileTreeDelegate, let treeView else { return nil }
        let item = convertIndexPathToItem(indexPath: indexPath)

        let actionProvider: UIContextMenuActionProvider = { _ in
            return fileTreeDelegate.fileTreeView(treeView, contextMenuForItem: item.id)
        }

        return UIContextMenuConfiguration(
            identifier: item.id as NSCopying, previewProvider: nil,
            actionProvider: actionProvider)
    }
}

extension TableViewDelegate: UITableViewDragDelegate, UITableViewDropDelegate {

    private func removeAllHighlightedCells(_ tableView: UITableView) {
        let indexPaths: [IndexPath] = dropDestinationHighlightedCells.compactMap { originalId in
            guard let index = (cachedTable.firstIndex { $0.id == originalId }) else { return nil }
            return IndexPath(row: index, section: 0)
        }
        dropDestinationHighlightedCells.removeAll()
        tableView.reloadRows(at: indexPaths, with: .none)
    }

    private func highlightAllCells(_ tableView: UITableView) {
        for cell in cachedTable {
            dropDestinationHighlightedCells.insert(cell.id)
        }
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
    }

    private func highlightCellAndItsChildren(_ tableView: UITableView, cell: UUID) {
        guard let range = indexRangeForCellAndItsChildren(cell: cell) else { return }

        let originalHighlightedCells = dropDestinationHighlightedCells
        dropDestinationHighlightedCells.removeAll()
        for cellToHighlight in cachedTable[range] {
            dropDestinationHighlightedCells.insert(cellToHighlight.id)
        }
        let indexPaths =
            range
            .indexPaths
            + originalHighlightedCells.compactMap { originalId in
                guard let index = (cachedTable.firstIndex { $0.id == originalId }) else {
                    return nil
                }
                return IndexPath(row: index, section: 0)
            }
        tableView.reloadRows(at: indexPaths, with: .none)
    }

    func tableView(
        _ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath
    ) -> [UIDragItem] {
        guard let fileTreeDataSource, let treeView else { return [] }
        let item = convertIndexPathToItem(indexPath: indexPath)
        let itemProvider =
            fileTreeDataSource.fileTreeView(treeView, itemProviderForItem: item.id)
            ?? NSItemProvider()
        let dragItem = UIDragItem(itemProvider: itemProvider)
        draggedCells.insert(item.id)
        dragItem.localObject = item.id
        return [dragItem]
    }

    func tableView(
        _ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator
    ) {
        guard let fileTreeDataSource, let fileTreeDelegate, let treeView else { return }

        let destinationUUID: UUID

        if let indexPath = coordinator.destinationIndexPath,
            indexPath.row < cachedTable.count
        {
            destinationUUID = convertIndexPathToItem(indexPath: indexPath).id
        } else {
            destinationUUID = fileTreeDataSource.rootItem(treeView)
        }

        let sourceUUIDs = coordinator.items.compactMap { $0.dragItem.localObject as? UUID }
        for sourceUUID in sourceUUIDs {
            fileTreeDelegate.fileTreeView(treeView, moveCell: sourceUUID, to: destinationUUID)
        }
    }

    private func getParentsOfItem(_ item: UUID) -> [UUID] {
        guard let itemIndex = (cachedTable.firstIndex { $0.id == item }) else { return [] }
        let item = cachedTable[itemIndex]
        var targetDepth = item.depth - 1

        var candidates = cachedTable[..<itemIndex]
        var result: [UUID] = []
        while let resultIndex = candidates.lastIndex(where: { $0.depth == targetDepth }) {
            result.append(candidates[resultIndex].id)
            candidates = cachedTable[..<resultIndex]
            targetDepth = targetDepth - 1
        }
        return result
    }

    func tableView(
        _ tableView: UITableView, dropSessionDidUpdate session: UIDropSession,
        withDestinationIndexPath destinationIndexPath: IndexPath?
    ) -> UITableViewDropProposal {
        guard destinationIndexPath != lastHoveredIndexPath else {
            if lastHoveredResult.operation == .move, let destinationIndexPath,
                Date()
                    > lastHoverStartedDate.addingTimeInterval(DISCLOSE_ON_HOVER_THRESHOLD)
            {
                let destinationItem = convertIndexPathToItem(indexPath: destinationIndexPath)
                if let treeView {
                    fileTreeDelegate?.fileTreeView(treeView, didExpandCellAt: destinationItem.id)
                }
                expandCell(tableView, at: destinationIndexPath)
                highlightCellAndItsChildren(tableView, cell: destinationItem.id)
            }
            return lastHoveredResult
        }
        lastHoverStartedDate = Date()
        lastHoveredIndexPath = destinationIndexPath

        guard let destinationIndexPath else {
            // Dropping on root
            for draggedCell in draggedCells {
                if getParentsOfItem(draggedCell).isEmpty {
                    lastHoveredResult = UITableViewDropProposal(operation: .cancel)
                    return UITableViewDropProposal(operation: .cancel)
                }
            }

            tableView.backgroundColor = UIColor(
                Color.init(id: "list.inactiveSelectionBackground"))
            highlightAllCells(tableView)
            lastHoveredResult = UITableViewDropProposal(operation: .move)
            return UITableViewDropProposal(operation: .move)
        }

        defer {
            tableView.backgroundColor = .clear
        }

        if destinationIndexPath.row < cachedTable.count {
            let destinationItem = convertIndexPathToItem(indexPath: destinationIndexPath)

            if !destinationItem.hasChildren {
                removeAllHighlightedCells(tableView)
                lastHoveredResult = UITableViewDropProposal(operation: .forbidden)
                return UITableViewDropProposal(operation: .forbidden)
            }

            let parentsOfItem = getParentsOfItem(destinationItem.id)
            let directParentsOfSourceItem = draggedCells.compactMap { getParentsOfItem($0).first }
            if draggedCells.contains(destinationItem.id)
                || directParentsOfSourceItem.contains(destinationItem.id)
                || draggedCells.contains(where: { parentsOfItem.contains($0) })
            {
                removeAllHighlightedCells(tableView)
                lastHoveredResult = UITableViewDropProposal(operation: .forbidden)
                return UITableViewDropProposal(operation: .forbidden)
            }
            highlightCellAndItsChildren(tableView, cell: destinationItem.id)
            lastHoveredResult = UITableViewDropProposal(operation: .move)
            return UITableViewDropProposal(operation: .move)
        } else {
            lastHoveredResult = UITableViewDropProposal(operation: .forbidden)
            return UITableViewDropProposal(operation: .forbidden)
        }
    }

    func tableView(_ tableView: UITableView, dropSessionDidEnd session: UIDropSession) {
        removeAllHighlightedCells(tableView)
        tableView.backgroundColor = .clear
        draggedCells.removeAll()
        lastHoveredIndexPath = nil
    }

    func tableView(_ tableView: UITableView, dropSessionDidExit session: UIDropSession) {
        removeAllHighlightedCells(tableView)
        tableView.backgroundColor = .clear
    }
}

class FileTreeView: UIView {
    weak var dataSource: (FileTreeViewDataSource)? {
        didSet {
            tableViewDelegate.fileTreeDataSource = dataSource
            tableView.reloadData()
        }
    }
    weak var delegate: FileTreeViewDelegate? {
        didSet {
            tableViewDelegate.fileTreeDelegate = delegate
        }
    }

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let buttonView = UIButton()
    private let tableViewDelegate: TableViewDelegate = TableViewDelegate()

    public func reloadData() {
        tableViewDelegate.reloadData(tableView)
    }

    public func reloadSectionHeader() {
        tableViewDelegate.reloadSectionHeader(tableView)
    }

    public func expandCells(cells: [UUID]) {
        for cell in cells {
            tableViewDelegate.expandCell(tableView, at: cell)
        }
    }

    public func contractCells(cells: [UUID]) {
        for cell in cells {
            tableViewDelegate.closeCell(tableView, at: cell)
        }
    }

    public func reloadCells(cells: [UUID]) {
        tableViewDelegate.reloadCells(tableView, at: cells)
    }

    public func scrollToCell(cell: UUID, scrollPosition: UITableView.ScrollPosition, animated: Bool)
    {
        tableViewDelegate.scrollToCell(
            tableView, at: cell, scrollPosition: scrollPosition, animated: animated)
    }

    @objc func didLongPress(_ recognizer: UIGestureRecognizer) {
        guard let delegate, let dataSource else { return }

        let rootItem = dataSource.rootItem(self)
        let menu = delegate.fileTreeView(self, contextMenuForItem: rootItem)

        let location = recognizer.location(in: tableView)

        buttonView.menu = menu
        buttonView.frame = CGRect(x: location.x, y: location.y, width: 1, height: 1)
        let r = buttonView.gestureRecognizers!.first(where: {
            $0.description.contains("UITouchDownGestureRecognizer")
        })!
        r.touchesBegan([], with: UIEvent())

    }

    init() {
        super.init(frame: CGRect.zero)
        tableViewDelegate.treeView = self
        tableView.dataSource = tableViewDelegate
        tableView.delegate = tableViewDelegate
        tableView.dragDelegate = tableViewDelegate
        tableView.dropDelegate = tableViewDelegate
        tableView.dragInteractionEnabled = true
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")

        buttonView.showsMenuAsPrimaryAction = true
        buttonView.isHidden = true
        addSubview(buttonView)
        let singleClick = UITapGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
        singleClick.buttonMaskRequired = .secondary
        singleClick.allowedTouchTypes = [UITouch.TouchType.indirectPointer.rawValue as NSNumber]
        self.addGestureRecognizer(singleClick)
        let longPress = UILongPressGestureRecognizer(
            target: self, action: #selector(didLongPress(_:)))
        longPress.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
        self.addGestureRecognizer(longPress)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tableView)
        tableView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        tableView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
    }

    override func layoutIfNeeded() {
        tableView.frame = self.frame
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
}

struct CellDecoration: Equatable {
    var backgroundColor: Color
    var text: String
}

struct FileTreeViewCell {
    var configuration: UIContentConfiguration
    var isHighlighted: Bool
    var decoration: CellDecoration?
}

protocol FileTreeViewDelegate: AnyObject {
    func fileTreeView(_ fileTreeView: FileTreeView, selectCell at: UUID)
    func fileTreeView(_ fileTreeView: FileTreeView, moveCell from: UUID, to: UUID)
    func fileTreeView(_ fileTreeView: FileTreeView, contextMenuForItem: UUID)
        -> UIMenu?
    func fileTreeView(_ fileTreeView: FileTreeView, didExpandCellAt item: UUID)
    func fileTreeView(_ fileTreeView: FileTreeView, didContractCellAt item: UUID)
}

protocol FileTreeViewDataSource: AnyObject {
    func fileTreeView(_ fileTreeView: FileTreeView, childrenOfItem: UUID) -> [UUID]?
    func fileTreeView(_ fileTreeView: FileTreeView, cellForItem: UUID) -> FileTreeViewCell
    func fileTreeView(_ fileTreeView: FileTreeView, hasChildrenForItem: UUID) -> Bool
    func fileTreeView(_ fileTreeView: FileTreeView, itemProviderForItem: UUID) -> NSItemProvider?
    func headerTitle(_ fileTreeView: FileTreeView) -> String?
    func rootItem(_ fileTreeView: FileTreeView) -> UUID
}
