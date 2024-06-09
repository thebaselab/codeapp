//
//  WebViewBase.swift
//  Code
//
//  Created by Ken Chung on 16/11/2022.
//

import WebKit

private var ToolbarHandle: UInt8 = 0

class SchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let url = urlSchemeTask.request.url!
        let mimeType = "text/\(url.pathExtension)"
        let response = URLResponse(
            url: url, mimeType: mimeType, expectedContentLength: -1, textEncodingName: nil)
        urlSchemeTask.didReceive(response)

        let fontName = url.absoluteString.components(separatedBy: "://").last?.components(
            separatedBy: "."
        ).first?.removingPercentEncoding

        if let fontName,
            let font = UIFont(name: fontName, size: 12),
            let ttfData = UIFont.data(from: font)
        {
            urlSchemeTask.didReceive(ttfData)
        }
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {

    }
}

class WebViewBase: KBWebViewBase {
    var isMessageHandlerAdded = false
    private var schemeHandler = SchemeHandler()

    init() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.preferences.setValue(true, forKey: "shouldAllowUserInstalledFonts")
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "fonts")
        super.init(frame: .zero, configuration: config)
        if #available(iOS 16.4, *) {
            self.isInspectable = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var candidateView: UIView? {
        var candidateView: UIView? = nil
        for view in self.scrollView.subviews {
            let description = String(describing: type(of: view))
            if description.hasPrefix("WKContent")
                || description.hasSuffix("_CustomInputAccessoryView")
            {
                candidateView = view
            }
        }
        return candidateView
    }

    func removeInputAccessoryView() {
        objc_setAssociatedObject(
            self, &ToolbarHandle, nil, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    func addInputAccessoryView(toolbar: UIView?) {
        guard let toolbar = toolbar else { return }
        guard let targetView = candidateView else { return }

        objc_setAssociatedObject(
            self, &ToolbarHandle, toolbar, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        let newClass: AnyClass? = classWithCustomAccessoryView(targetView: targetView)
        object_setClass(targetView, newClass!)
    }

    func removeUIDropInteraction() {
        func findInteractionView(in subviews: [UIView]) -> UIView? {
            for subview in subviews {
                for interaction in subview.interactions {
                    if interaction is UIDragInteraction {
                        return subview
                    }
                }
                return findInteractionView(in: subview.subviews)
            }
            return nil
        }

        if let interactionView = findInteractionView(in: subviews) {
            for interaction in interactionView.interactions {
                if interaction is UIDragInteraction || interaction is UIDropInteraction {
                    interactionView.removeInteraction(interaction)
                }
            }
        }
    }

    private func classWithCustomAccessoryView(targetView: UIView) -> AnyClass? {
        guard let targetSuperClass = targetView.superclass else { return nil }
        let customInputAccessoryViewClassName = "\(targetSuperClass)_CustomInputAccessoryView"

        var newClass: AnyClass? = NSClassFromString(customInputAccessoryViewClassName)
        if newClass == nil {
            newClass = objc_allocateClassPair(
                object_getClass(targetView), customInputAccessoryViewClassName, 0)
        } else {
            return newClass
        }

        let newMethod = class_getInstanceMethod(
            WebViewBase.self, #selector(WebViewBase.getCustomInputAccessoryView))
        class_addMethod(
            newClass.self, #selector(getter: UIResponder.inputAccessoryView),
            method_getImplementation(newMethod!), method_getTypeEncoding(newMethod!))

        objc_registerClassPair(newClass!)

        return newClass
    }

    @objc func getCustomInputAccessoryView() -> UIView? {
        var superWebView: UIView? = self
        while (superWebView != nil) && !(superWebView is WKWebView) {
            superWebView = superWebView?.superview
        }
        let customInputAccessory = objc_getAssociatedObject(superWebView as Any, &ToolbarHandle)
        superWebView?.inputAssistantItem.leadingBarButtonGroups = []
        superWebView?.inputAssistantItem.trailingBarButtonGroups = []
        return customInputAccessory as? UIView
    }

    override open var inputAccessoryView: UIView? {
        // remove/replace the default accessory view
        return nil
    }
}
