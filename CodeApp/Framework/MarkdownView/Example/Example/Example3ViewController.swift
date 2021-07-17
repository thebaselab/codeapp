import UIKit
import MarkdownView
import SafariServices

class Example3ViewController: UIViewController {

  @IBOutlet weak var mdView: MarkdownView!

  override func viewDidLoad() {
    super.viewDidLoad()

    mdView.isScrollEnabled = false

    mdView.onRendered = { height in
      print(height)
    }

    mdView.onTouchLink = { [weak self] request in
      guard let url = request.url else { return false }

      if url.scheme == "file" {
        return true
      } else if url.scheme == "https" {
        let safari = SFSafariViewController(url: url)
        self?.present(safari, animated: true, completion: nil)
        return false
      } else {
        return false
      }
    }

    let session = URLSession(configuration: .default)
    let url = URL(string: "https://raw.githubusercontent.com/matteocrippa/awesome-swift/master/README.md")!
    let task = session.dataTask(with: url) { [weak self] data, _, _ in
      let str = String(data: data!, encoding: String.Encoding.utf8)
      DispatchQueue.main.async {
        self?.mdView.load(markdown: str)
      }
    }
    task.resume()
  }

}
