//
//  AppError.swift
//  Code
//
//  Created by Ken Chung on 20/11/2022.
//

import Foundation

enum AppError: String, LocalizedError {
    case unknownFileFormat = "errors.unknown_file_format"
    case editorDoesNotExist = "errors.editor_does_not_exist"
}
