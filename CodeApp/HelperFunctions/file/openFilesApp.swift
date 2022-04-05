//
//  openFilesApp.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import Foundation
import UIKit

func openSharedFilesApp(urlString: String) {
    let sharedurl = urlString.replacingOccurrences(of: "file://", with: "shareddocuments://")
    if let furl: URL = URL(string: sharedurl) {
        UIApplication.shared.open(furl, options: [:], completionHandler: nil)
    }
}
