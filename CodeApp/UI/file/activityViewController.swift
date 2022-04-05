//
//  activityViewController.swift
//  Code App
//
//  Created by Ken Chung on 7/12/2020.
//

import SwiftUI
import UIKit

class ActivityViewController: UIViewController {

    var urls: [URL]!

    @objc func share() {
        let vc = UIActivityViewController(activityItems: urls, applicationActivities: [])
        present(
            vc,
            animated: true,
            completion: nil)
        vc.popoverPresentationController?.sourceView = self.view
    }
}

struct SwiftUIActivityViewController: UIViewControllerRepresentable {

    let activityViewController = ActivityViewController()

    func makeUIViewController(context: Context) -> ActivityViewController {
        activityViewController
    }
    func updateUIViewController(_ uiViewController: ActivityViewController, context: Context) {
    }
    func share(urls: [URL]) {
        activityViewController.urls = urls
        activityViewController.share()
    }
}
