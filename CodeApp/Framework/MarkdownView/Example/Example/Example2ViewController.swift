import UIKit
import MarkdownView

class Example2ViewController: UIViewController {

  @IBOutlet weak var mdView: MarkdownView!

  override func viewDidLoad() {
    super.viewDidLoad()

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
