//
//  SourceControlError.swift
//  Code
//
//  Created by Ken Chung on 12/11/2022.
//

import Foundation

enum SourceControlError: Error {
    case gitServiceProviderUnavailable
    case noChangesAvailable
    case invalidURL
    case authorIdentityMissing
}
