import UIKit
import SwiftUI

/// Root UIKit controller required by the keyboard extension point.
/// Hosts a SwiftUI KeyboardView via UIHostingController.
final class KeyboardViewController: UIInputViewController {

    private var hostingController: UIHostingController<KeyboardRootView>?
    private var viewModel: KeyboardViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel = KeyboardViewModel(textProxy: textDocumentProxy)

        let rootView = KeyboardRootView(viewModel: viewModel, inputController: self)
        let hosting = UIHostingController(rootView: rootView)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.backgroundColor = .clear

        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        hostingController = hosting
    }

    // Called by KeyboardView to switch to next keyboard (globe tap)
    func advanceToNextKeyboard() {
        advanceToNextInputMode()
    }

    // Called by KeyboardView to dismiss keyboard
    func dismissKeyboard() {
        dismissKeyboard()
    }
}
