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

final class NpmScriptParsingTests: XCTestCase {

    func testSplitScriptLineKeepsOperatorsAndQuotedText() {
        let commands = splitScriptLine(
            "rm -rf dist && NODE_ENV=production nuxt build || echo 'a && b'; echo done")

        XCTAssertEqual(
            commands.map(\.1),
            [
                "rm -rf dist", "NODE_ENV=production nuxt build", "echo 'a && b'", "echo done",
            ])
        XCTAssertNil(commands[0].0)
        XCTAssertEqual(commands[1].0, .and)
        XCTAssertEqual(commands[2].0, .or)
        XCTAssertEqual(commands[3].0, .sequence)
    }

    func testSplitScriptLineDoesNotTreatRedirectAsAnd() {
        XCTAssertEqual(splitScriptLine("tsc 2>&1").map(\.1), ["tsc 2>&1"])
    }

    func testTokenizeCommandHandlesQuotesAndEscapes() {
        let words = tokenizeCommand(#"vite --host "0.0.0.0" --base 'my dir' a\ b"#)
        XCTAssertEqual(
            words.map(\.value), ["vite", "--host", "0.0.0.0", "--base", "my dir", "a b"])
        XCTAssertFalse(words.contains(where: \.needsShell))
    }

    func testTokenizeCommandFlagsShellSyntax() {
        XCTAssertTrue(tokenizeCommand("eslint src/**/*.ts")[1].needsShell)
        XCTAssertTrue(tokenizeCommand(#"vite --port "$PORT""#)[2].needsShell)
        XCTAssertTrue(tokenizeCommand("tsc > build.log")[1].needsShell)
        XCTAssertFalse(tokenizeCommand("echo 'a|b'")[1].needsShell)
    }

    func testEnvironmentAssignment() {
        XCTAssertEqual(environmentAssignment("NODE_ENV=production")?.name, "NODE_ENV")
        XCTAssertEqual(environmentAssignment("NODE_ENV=production")?.value, "production")
        XCTAssertNil(environmentAssignment("--port=3000"))
        XCTAssertNil(environmentAssignment("=value"))
        XCTAssertNil(environmentAssignment("1VAR=value"))
    }

    func testShellQuoted() {
        XCTAssertEqual(shellQuoted("--port"), "--port")
        XCTAssertEqual(shellQuoted("my host"), "'my host'")
        XCTAssertEqual(shellQuoted("it's"), #"'it'\''s'"#)
    }
}
