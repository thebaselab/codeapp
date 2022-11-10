//
//  RemoteType.swift
//  Code
//
//  Created by Ken Chung on 10/11/2022.
//

import Foundation

enum RemoteType: String, CaseIterable, Identifiable {
    case sftp
    case ftp
    case ftps
    var id: String { self.rawValue }
}

struct RemoteHost: Codable {
    var url: String
    var useKeyAuth: Bool
}
