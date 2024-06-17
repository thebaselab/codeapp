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

    func testParseRemoteURL_userExtension() throws {
        let url = URL(string: "git@github.com:thebaselab/codeapp.git")!
        let parsed = LocalGitCredentialsHelper.parseRemoteURL(url: url)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed!.host, "github.com")
        XCTAssertEqual(parsed!.scheme, "ssh")
        XCTAssertEqual(parsed!.path, "/thebaselab/codeapp.git")
    }

    func testParseRemoteURL_noUserExtension() throws {
        let url = URL(string: "git@github.com:/codeapp.git")!
        let parsed = LocalGitCredentialsHelper.parseRemoteURL(url: url)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed!.host, "github.com")
        XCTAssertEqual(parsed!.scheme, "ssh")
        XCTAssertEqual(parsed!.path, "/codeapp.git")
    }
}
