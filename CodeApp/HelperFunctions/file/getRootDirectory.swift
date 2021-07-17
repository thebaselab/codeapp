//
//  getRootDirectory.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import Foundation

func getRootDirectory() -> URL{
    if let documentsPathURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        return documentsPathURL
    }else{
        fatalError("Could not locate Document Directory")
    }
}
