//
//  String+throwingRemovingPercentEncoding.swift
//  Code
//
//  Created by Ken Chung on 14/8/2023.
//

import Foundation

extension String {
    var removingPercentEncoding: String {
        get throws {
            guard let result = self.removingPercentEncoding else {
                throw NSError(descriptionKey: "Invalid percent-encoding sequence")
            }
            return result
        }
    }
}
