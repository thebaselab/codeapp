import Foundation

// extension for swift package manager
extension MarkdownView {
    var htmlURL: URL? {
        let bundle = Bundle.module
        return bundle.url(forResource: "index",
                          withExtension: "html") ??
               bundle.url(forResource: "index",
                          withExtension: "html",
                          subdirectory: "MarkdownView.bundle")
    }
}