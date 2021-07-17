import UIKit
import MarkdownView
import SafariServices

class Example4ViewController: UIViewController {

  @IBOutlet weak var searchBar: UISearchBar!
  @IBOutlet weak var mdView: MarkdownView!

  override func viewDidLoad() {
    super.viewDidLoad()

    searchBar.delegate = self

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
  }

}

extension Example4ViewController: UISearchBarDelegate {

  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    if let urlStr = searchBar.text, let url = URL(string: urlStr) {
      let session = URLSession(configuration: .default)
      let task = session.dataTask(with: url) { [weak self] data, _, _ in
        guard let data = data else { return }

        let str = String(data: data, encoding: String.Encoding.utf8)
        DispatchQueue.main.async {
          self?.mdView.load(markdown: str)
        }

      }
      task.resume()
    } else {
      print("[ERROR] Invalid URL detected.")
    }
  }
}
