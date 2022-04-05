//
//  UIApplication+getSafeArea.swift
//  Code
//
//  Created by Ken Chung on 6/3/2022.
//

import UIKit

extension UIApplication {
    enum uiedge {
        case top
        case bottom
        case left
        case right
    }

    func getSafeArea(edge: uiedge) -> CGFloat {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .map({ $0 as? UIWindowScene })
            .compactMap({ $0 })
            .first?.windows
            .filter({ $0.isKeyWindow }).first

        guard let insets = keyWindow?.safeAreaInsets else {
            return 0
        }

        switch edge {
        case .top:
            return insets.top
        case .bottom:
            return insets.bottom
        case .left:
            return insets.left
        case .right:
            return insets.right
        }

    }
}
