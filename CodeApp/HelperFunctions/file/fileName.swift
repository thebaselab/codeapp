//
//  fileName.swift
//  Code App
//
//  Created by Ken Chung on 7/12/2020.
//

import Foundation

func newFileName(defaultName: String, extensionName: String, urlString: String) -> String {
    var num = 1

    func checkFileExist(fileName: String) -> Bool {
        let path = urlString + fileName
        let url = URL(string: path)
        return FileManager.default.fileExists(atPath: url!.path)
    }

    if checkFileExist(fileName: (defaultName + (extensionName == "" ? "" : "." + extensionName))) {
        while num < 100 {
            if checkFileExist(
                fileName: (extensionName == ""
                    ? defaultName + "(\(num))" : defaultName + "(\(num))" + "." + extensionName))
            {
                num += 1
            } else {
                break
            }
        }
    } else {
        return (extensionName == "" ? defaultName : defaultName + "." + extensionName)
    }
    return (defaultName + "(\(num))" + (extensionName == "" ? "" : "." + extensionName))
}
