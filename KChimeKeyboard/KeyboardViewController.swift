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

        // Observe paywall deep-link requests from the SwiftUI view model
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleOpenPaywall),
            name: .kchimeOpenPaywall, object: nil
        )
    }

    /// Switch to the next system keyboard (globe button).
    func advanceToNextKeyboard() {
        advanceToNextInputMode()
    }

    @objc private func handleOpenPaywall() {
        guard let url = URL(string: "kchime://paywall") else { return }
        // Keyboard extensions use the responder chain to open URLs
        var responder: UIResponder? = self
        while let r = responder {
            if let application = r as? UIApplication {
                application.open(url)
                return
            }
            responder = r.next
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release cached data to stay within keyboard extension memory limits (~50 MB).
        viewModel?.suggestions = []
        viewModel?.longerAlternative = nil
    }

    /// Dismiss the keyboard — called by the down-chevron button in the saved bar.
    func dismissKeyboardAction() {
        // dismissKeyboard() is a UIInputViewController method that hides the keyboard.
        // We alias it here to avoid a recursive call from the SwiftUI side.
        (self as UIInputViewController).dismissKeyboard()
    }
}
