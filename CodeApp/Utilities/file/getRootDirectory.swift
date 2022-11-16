//
//  getRootDirectory.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import Foundation

func getRootDirectory() -> URL {
    // We want ./private prefix because all other files have it
    if let documentsPathURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        .first
    {
        #if targetEnvironment(simulator)
            return documentsPathURL
        #else
            if let standardURL = URL(
                string: documentsPathURL.absoluteString.replacingOccurrences(
                    of: "file:///", with: "file:///private/"))
            {
                return standardURL
            } else {
                return documentsPathURL
            }
        #endif
    } else {
        fatalError("Could not locate Document Directory")
    }
}
