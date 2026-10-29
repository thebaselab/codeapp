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

    func testNormalizeRemoteURL_bareIPWithPort() throws {
        let urlString = "192.1.1.1:3000/repo.git"
        let normalized = LocalGitCredentialsHelper.normalizeRemoteURL(urlString)

        XCTAssertEqual(normalized, "http://192.1.1.1:3000/repo.git")
        XCTAssertNotNil(URL(string: normalized))
        XCTAssertEqual(URL(string: normalized)!.host, "192.1.1.1")
        XCTAssertEqual(URL(string: normalized)!.port, 3000)
    }

    func testNormalizeRemoteURL_hostnameWithPort() throws {
        let urlString = "forgejo.local:3000/user/repo.git"
        let normalized = LocalGitCredentialsHelper.normalizeRemoteURL(urlString)

        XCTAssertEqual(normalized, "http://forgejo.local:3000/user/repo.git")
        XCTAssertNotNil(URL(string: normalized))
        XCTAssertEqual(URL(string: normalized)!.host, "forgejo.local")
        XCTAssertEqual(URL(string: normalized)!.port, 3000)
    }

    func testNormalizeRemoteURL_scpLikeSyntax() throws {
        let urlString = "git@github.com:user/repo.git"
        let normalized = LocalGitCredentialsHelper.normalizeRemoteURL(urlString)

        // Should not be modified - let parseRemoteURL handle it
        XCTAssertEqual(normalized, urlString)
    }

    func testNormalizeRemoteURL_fullyQualifiedHTTPS() throws {
        let urlString = "https://github.com/user/repo.git"
        let normalized = LocalGitCredentialsHelper.normalizeRemoteURL(urlString)

        // Should not be modified - already valid
        XCTAssertEqual(normalized, urlString)
    }

    func testNormalizeRemoteURL_fullyQualifiedHTTP() throws {
        let urlString = "http://192.1.1.1:3000/repo.git"
        let normalized = LocalGitCredentialsHelper.normalizeRemoteURL(urlString)

        // Should not be modified - already valid
        XCTAssertEqual(normalized, urlString)
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
