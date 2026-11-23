import SafariServices
import SwiftUI

struct SafariTarget: Identifiable {
    let id = UUID()
    let url: URL
}

/// Внутренний браузер для входа в аккаунт DeepSeek.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredBarTintColor = .black
        controller.preferredControlTintColor = .white
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
