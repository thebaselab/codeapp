//
//  String+C.swift
//  OpenTerm
//
//  Created by Louis D'hauwe on 08/04/2018.
//  Copyright © 2018 Silver Fox. All rights reserved.
//
import Foundation

extension String {

    func toCString() -> UnsafePointer<Int8>? {
        let nsSelf: NSString = self as NSString
        return nsSelf.cString(using: String.Encoding.utf8.rawValue)
    }

    var utf8CString: UnsafeMutablePointer<Int8> {
        return UnsafeMutablePointer(mutating: (self as NSString).utf8String!)
    }

}
