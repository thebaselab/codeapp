//
//  focusableTextfield.swift
//  Code App
//
//  Created by Ken Chung on 14/12/2020.
//

import SwiftUI

struct focusableTextField: UIViewRepresentable {
    
    class Coordinator: NSObject, UITextFieldDelegate {
        
        @Binding var text: String
        @Binding var isRenaming: Bool
        var didBecomeFirstResponder = false
        var URL: URL
        var onFileNameChange: (() -> Void)
        
        init(text: Binding<String>, isRenaming: Binding<Bool>, url: URL, onChange: @escaping (() -> Void)) {
            _text = text
            _isRenaming = isRenaming
            URL = url
            onFileNameChange = onChange
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            text = textField.text ?? ""
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            textField.selectAll(nil)
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if text.isEmpty{
                return false
            }
            onFileNameChange()
            isRenaming = false
            textField.resignFirstResponder()
            return true
        }
        
    }
    
    @Binding var text: String
    @Binding var isRenaming: Bool
    var isFirstResponder: Bool = false
    var url: URL
    var onFileNameChange: (() -> Void)
    
    func makeUIView(context: UIViewRepresentableContext<focusableTextField>) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.textColor = UIColor.init(named: "T1")
        textField.font = .systemFont(ofSize: 14, weight: .light)
        textField.returnKeyType = .done
        textField.text = text
        return textField
    }
    
    func makeCoordinator() -> focusableTextField.Coordinator {
        return Coordinator(text: $text, isRenaming: $isRenaming, url: url, onChange: onFileNameChange)
    }
    
    func updateUIView(_ uiView: UITextField, context: UIViewRepresentableContext<focusableTextField>) {
        if text == "" {
            uiView.text = ""
        }
        if isFirstResponder && !context.coordinator.didBecomeFirstResponder  {
            uiView.becomeFirstResponder()
            context.coordinator.didBecomeFirstResponder = true
        }
    }
}
