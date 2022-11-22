//
//  AppError.swift
//  Code
//
//  Created by Ken Chung on 20/11/2022.
//

import Foundation

// TODO: Add localization entries
enum AppError: String {
    case unknownFileFormat = "errors.unknown_file_format"
    case editorDoesNotExist = "errors.editor_does_not_exist"
}

extension AppError: LocalizedError {
    var errorDescription: String? {
        NSLocalizedString(self.rawValue, comment: "")
    }
}
