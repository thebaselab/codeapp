import UIKit

final class ViewController: UIViewController {

  override func viewDidLoad() {
    super.viewDidLoad()

    let stackView = UIStackView()
    stackView.axis = .vertical

    let example1Button = UIButton()
    example1Button.setTitle("Code Only Example", for: .normal)
    example1Button.addTarget(self, action: #selector(openExample1), for: .touchUpInside)

    let example2Button = UIButton()
    example2Button.setTitle("Storyboard Example", for: .normal)
    example2Button.addTarget(self, action: #selector(openExample2), for: .touchUpInside)

    let example3Button = UIButton()
    example3Button.setTitle("ScrollView Example", for: .normal)
    example3Button.addTarget(self, action: #selector(openExample3), for: .touchUpInside)

    let example4Button = UIButton()
    example4Button.setTitle("Arbitrary markdown Example", for: .normal)
    example4Button.addTarget(self, action: #selector(openExample4), for: .touchUpInside)

    [
      example1Button,
      example2Button,
      example3Button,
      example4Button
    ].forEach { button in

      button.setTitleColor(UIColor.systemBlue, for: .normal)
      button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
      button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
      stackView.addArrangedSubview(button)

    }

    view.addSubview(stackView)
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
  }

  @objc func openExample1(sender: Any) {
    let example = storyboard?.instantiateViewController(
      withIdentifier: "Example1") as! Example1ViewController
    navigationController?.pushViewController(example, animated: true)
  }

  @objc func openExample2(sender: Any) {
    let example = storyboard?.instantiateViewController(
      withIdentifier: "Example2") as! Example2ViewController
    navigationController?.pushViewController(example, animated: true)
  }

  @objc func openExample3(sender: Any) {
    let example = storyboard?.instantiateViewController(
      withIdentifier: "Example3") as! Example3ViewController
    navigationController?.pushViewController(example, animated: true)
  }

  @objc func openExample4(sender: Any) {
    let example = storyboard?.instantiateViewController(
      withIdentifier: "Example4") as! Example4ViewController
    navigationController?.pushViewController(example, animated: true)
  }
}
