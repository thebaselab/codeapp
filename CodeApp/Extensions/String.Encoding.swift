//
//  encoding.swift
//  Code App
//
//  Created by Ken Chung on 13/12/2020.
//

import Foundation

extension String.Encoding {
    static let gb_18030_2000 = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
    static let EUC_KR = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)))
}

let encodingTable: [String.Encoding: String] = [
    .utf8: "UTF-8", .EUC_KR: "EUC_KR", .gb_18030_2000: "GB18030", .windowsCP1252: "WINDOWS-1252",
    .ascii: "ASCII",
]
