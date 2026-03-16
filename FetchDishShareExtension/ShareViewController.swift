import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Entry point for the Share Extension.
/// Extracts the shared URL from Safari, then presents a SwiftUI view to parse and save the recipe.
@objc(ShareViewController)
class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Extract the URL from the extension context
        extractURL { [weak self] url in
            guard let self else { return }

            DispatchQueue.main.async {
                let shareView = ShareView(
                    url: url,
                    extensionContext: self.extensionContext
                )

                let hostingController = UIHostingController(rootView: shareView)
                hostingController.view.frame = self.view.bounds
                hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

                self.addChild(hostingController)
                self.view.addSubview(hostingController.view)
                hostingController.didMove(toParent: self)
            }
        }
    }

    /// Extract the first URL from the share extension input items.
    private func extractURL(completion: @escaping (String?) -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion(nil)
            return
        }

        for item in items {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                // Try URL type first
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
                        if let url = data as? URL {
                            completion(url.absoluteString)
                            return
                        }
                        if let urlData = data as? Data, let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                            completion(url.absoluteString)
                            return
                        }
                        completion(nil)
                    }
                    return
                }

                // Fallback: try plain text (might be a URL string)
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
                        if let text = data as? String, text.hasPrefix("http") {
                            completion(text)
                            return
                        }
                        completion(nil)
                    }
                    return
                }
            }
        }

        completion(nil)
    }
}
