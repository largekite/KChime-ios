import UIKit
import SwiftUI
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        extractSharedText { [weak self] text in
            DispatchQueue.main.async { self?.presentShareView(prefilledText: text) }
        }
    }

    private func extractSharedText(completion: @escaping (String) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = item.attachments?.first else {
            completion("")
            return
        }

        if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier) { data, _ in
                completion((data as? String) ?? "")
            }
        } else if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            attachment.loadItem(forTypeIdentifier: UTType.url.identifier) { data, _ in
                let url = data as? URL
                completion(url?.absoluteString ?? "")
            }
        } else {
            completion("")
        }
    }

    private func presentShareView(prefilledText: String) {
        let viewModel = ShareViewModel(prefilledText: prefilledText)
        let shareView = ShareView(viewModel: viewModel) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }

        let hosting = UIHostingController(rootView: shareView)
        hosting.view.backgroundColor = .clear
        hosting.modalPresentationStyle = .pageSheet

        if let sheet = hosting.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }

        present(hosting, animated: true)

        // Auto-generate on open
        Task { await viewModel.generate() }
    }
}
