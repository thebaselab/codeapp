//
//  MenuView.swift
//  EightyFive
//
//  Created by Ken Chung on 30/6/2022.
//

import SwiftUI
import UIKit

struct MenuButtonView<S>: UIViewRepresentable {

    struct Option {
        let value: S
        let title: String
        let iconSystemName: String?
    }

    let options: [Option]
    let onSelect: (S) -> (Void)
    let title: String
    let iconName: String?
    let menuTitle: String?

    private func updateButton(_ button: UIButton) {
        button.configuration?.title = title
        button.tintColor = UIColor(Color.init(id: "statusBar.foreground"))
        button.setTitleColor(button.tintColor, for: .normal)

        if let iconName = iconName {
            button.setImage(
                UIImage(
                    systemName: iconName,
                    withConfiguration: UIImage.SymbolConfiguration(
                        pointSize: 12, weight: .regular, scale: .default)), for: .normal)
        }
        let children = options.map { option in
            UIAction(
                title: option.title,
                image: option.iconSystemName == nil
                    ? nil : UIImage(systemName: option.iconSystemName!),
                state: .off,
                handler: {
                    _action in
                    onSelect(option.value)
                })
        }
        if let menuTitle {
            button.menu = UIMenu(
                title: NSLocalizedString(menuTitle, comment: ""), children: children)
        } else {
            button.menu = UIMenu(children: children)
        }
    }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.imagePadding = 4
        config.buttonSize = .mini
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 12)
            return outgoing
        }
        button.showsMenuAsPrimaryAction = true
        button.configuration = config
        updateButton(button)
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        updateButton(button)
    }
}
