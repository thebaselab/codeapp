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
