import Foundation

// extension for cocoapods and carthage
extension MarkdownView {
    var htmlURL: URL? {
        let bundle = Bundle(for: MarkdownView.self)
        return bundle.url(forResource: "index",
                          withExtension: "html") ??
               bundle.url(forResource: "index",
                          withExtension: "html",
                          subdirectory: "MarkdownView.bundle")
    }
}
