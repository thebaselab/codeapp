//
//  SearchServiceProvider.swift
//  Code
//
//  Created by Ken Chung on 14/4/2022.
//

import Foundation

struct SearchResult: Identifiable {
    let id = UUID()
    let line_num: Int
    let line: String
}

protocol SearchServiceProvider {
    func search(str: String, path: String, completionHandler: ([SearchResult], Error?) -> Void)
}
