//
//  langListInit.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import Foundation

func langListInit() -> [Bool] {
    let defaults = UserDefaults.standard

    let languageArray = [Bool](repeating: true, count: 200)
    defaults.set(languageArray, forKey: "languageList")
    return languageArray
}
