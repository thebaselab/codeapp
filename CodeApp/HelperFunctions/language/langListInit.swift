//
//  langListInit.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import Foundation

func langListInit() -> [Bool]{
    let defaults = UserDefaults.standard
    
    if var languageList = defaults.object(forKey: "languageList") as? [Bool]{
        if let lastReadVersion = UserDefaults.standard.string(forKey: "changelog.lastread"), let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, (currentVersion == "1.2.4") , lastReadVersion != currentVersion {
            languageList[0] = true
            languageList[1] = true
            languageList[2] = true
            languageList[3] = true
            languageList[4] = true
            defaults.set(languageList, forKey: "languageList")
        }
        return languageList
    }else{
        let languageArray = [Bool](repeating: true, count: 200)
        defaults.set(languageArray, forKey: "languageList")
        return languageArray
    }
}
