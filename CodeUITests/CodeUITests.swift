//
//  CodeUITests.swift
//  CodeUITests
//
//  Created by Ken Chung on 1/2/2023.
//

import SwiftUI
import XCTest

@testable import CodeUI

final class CodeUITests: XCTestCase {

    override func setUpWithError() throws {
        // Clean all UserDefaults
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
    }

    //  https://github.com/thebaselab/codeapp/issues/746
    @MainActor
    func testAppendAndFocusNewEditor() throws {
        let app = MainApp()

        let editorOne = EditorInstance(view: AnyView(EmptyView()), title: "editorOne")
        let editorTwo = EditorInstance(view: AnyView(EmptyView()), title: "editorTwo")

        app.appendAndFocusNewEditor(editor: editorOne)
        app.appendAndFocusNewEditor(editor: editorTwo)

        XCTAssertEqual(app.editors.count, 1)
    }

    @MainActor
    func testAppendAndFocusNewEditor_alwaysInNewTab() throws {
        let app = MainApp()

        let editorOne = EditorInstance(view: AnyView(EmptyView()), title: "editorOne")
        let editorTwo = EditorInstance(view: AnyView(EmptyView()), title: "editorTwo")

        app.appendAndFocusNewEditor(editor: editorOne)
        app.appendAndFocusNewEditor(editor: editorTwo, alwaysInNewTab: true)

        XCTAssertEqual(app.editors.count, 2)
    }

    @MainActor
    func testAppendAndFocusNewEditor_alwaysInNewTabWithUserOption() throws {
        UserDefaults.standard.set(true, forKey: "alwaysOpenInNewTab")

        let app = MainApp()

        let editorOne = EditorInstance(view: AnyView(EmptyView()), title: "editorOne")
        let editorTwo = EditorInstance(view: AnyView(EmptyView()), title: "editorTwo")

        app.appendAndFocusNewEditor(editor: editorOne)
        app.appendAndFocusNewEditor(editor: editorTwo)

        XCTAssertEqual(app.editors.count, 2)

        UserDefaults.standard.removeObject(forKey: "alwaysOpenInNewTab")
    }

    @MainActor
    func testLocalFileManagerTrashItem() async throws {
        let app = MainApp()

        let trashDirectory = app.workSpaceStorage.currentDirectory._url!.appending(path: ".Trash")
        try! FileManager.default.removeItem(at: trashDirectory)

        let testFile = app.workSpaceStorage.currentDirectory._url!.appending(path: "test")
        try! "".write(to: testFile, atomically: true, encoding: .utf8)
        try! await app.workSpaceStorage.removeItem(at: testFile, trashItemIfAvailable: true)

        let fileCount = try! FileManager.default.contentsOfDirectory(
            at: trashDirectory, includingPropertiesForKeys: nil)
        print(fileCount)
        XCTAssertEqual(fileCount.count, 1)

        let testFile2 = app.workSpaceStorage.currentDirectory._url!.appending(path: "test2")
        try! "".write(to: testFile2, atomically: true, encoding: .utf8)
        try! await app.workSpaceStorage.removeItem(at: testFile2, trashItemIfAvailable: false)

        let fileCount2 = try! FileManager.default.contentsOfDirectory(
            at: trashDirectory, includingPropertiesForKeys: nil
        ).count
        XCTAssertEqual(fileCount2, 1)
    }
}
