//
//  CodeUITests.swift
//  CodeUITests
//
//  Created by Ken Chung on 1/2/2023.
//

import XCTest
import SwiftUI
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
}
