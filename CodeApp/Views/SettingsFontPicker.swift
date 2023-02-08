// Created by SwapnanilDhol: https://github.com/SwapnanilDhol/SUIFontPicker/blob/main/Sources/SUIFontPicker/SUIFontPicker.swift

import SwiftUI
import UIKit

public struct SettingsFontPicker: UIViewControllerRepresentable {

    @Environment(\.presentationMode) var presentationMode
    @State var showAllFonts: Bool
    var onFontPick: (UIFontDescriptor) -> Void

    public func makeUIViewController(
        context: UIViewControllerRepresentableContext<SettingsFontPicker>
    )
        -> UIFontPickerViewController
    {
        let configuration = UIFontPickerViewController.Configuration()
        configuration.includeFaces = false
        configuration.displayUsingSystemFont = false
        configuration.filteredTraits = showAllFonts ? [] : .traitMonoSpace

        let vc = UIFontPickerViewController(configuration: configuration)
        vc.delegate = context.coordinator
        return vc
    }

    public func makeCoordinator() -> SettingsFontPicker.Coordinator {
        return Coordinator(self, onFontPick: self.onFontPick)
    }

    public class Coordinator: NSObject, UIFontPickerViewControllerDelegate {

        var parent: SettingsFontPicker
        private let onFontPick: (UIFontDescriptor) -> Void

        init(_ parent: SettingsFontPicker, onFontPick: @escaping (UIFontDescriptor) -> Void) {
            self.parent = parent
            self.onFontPick = onFontPick
        }

        public func fontPickerViewControllerDidPickFont(
            _ viewController: UIFontPickerViewController
        ) {
            guard let descriptor = viewController.selectedFontDescriptor else { return }
            onFontPick(descriptor)
            parent.presentationMode.wrappedValue.dismiss()
        }

        public func fontPickerViewControllerDidCancel(_ viewController: UIFontPickerViewController)
        {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }

    public func updateUIViewController(
        _ uiViewController: UIFontPickerViewController,
        context: UIViewControllerRepresentableContext<SettingsFontPicker>
    ) {

    }
}
