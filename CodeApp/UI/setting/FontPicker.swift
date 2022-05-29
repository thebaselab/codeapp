// Created by SwapnanilDhol: https://github.com/SwapnanilDhol/SUIFontPicker/blob/main/Sources/SUIFontPicker/SUIFontPicker.swift

import SwiftUI
import UIKit

public struct FontPicker: UIViewControllerRepresentable {

    @Environment(\.presentationMode) var presentationMode
    private let onFontPick: (UIFontDescriptor) -> Void

    public init(onFontPick: @escaping (UIFontDescriptor) -> Void) {
        self.onFontPick = onFontPick
    }

    public func makeUIViewController(context: UIViewControllerRepresentableContext<FontPicker>)
        -> UIFontPickerViewController
    {
        let configuration = UIFontPickerViewController.Configuration()
        configuration.includeFaces = false
        configuration.displayUsingSystemFont = false

        let vc = UIFontPickerViewController(configuration: configuration)
        vc.delegate = context.coordinator
        return vc
    }

    public func makeCoordinator() -> FontPicker.Coordinator {
        return Coordinator(self, onFontPick: self.onFontPick)
    }

    public class Coordinator: NSObject, UIFontPickerViewControllerDelegate {

        var parent: FontPicker
        private let onFontPick: (UIFontDescriptor) -> Void

        init(_ parent: FontPicker, onFontPick: @escaping (UIFontDescriptor) -> Void) {
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
        context: UIViewControllerRepresentableContext<FontPicker>
    ) {

    }
}
