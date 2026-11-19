import Combine
import SwiftUI
import WebKit

/// Una scheda del browser.
@MainActor
final class BrowserTab: NSObject, ObservableObject, Identifiable {
    let id = UUID()
    let webView: WKWebView

    @Published var title = ""
    @Published var url: URL?
    @Published var progress: Double = 0
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    /// true finché la scheda mostra la "Nuova scheda" del gufo.
    @Published var showsNewTab = true
    @Published var blockedOnPage = 0
    @Published var errorMessage: String?

    init(configuration: WKWebViewConfiguration) {
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = UIColor(Owl.plum)

        webView.publisher(for: \.title).map { $0 ?? "" }.assign(to: &$title)
        webView.publisher(for: \.url).assign(to: &$url)
        webView.publisher(for: \.estimatedProgress).assign(to: &$progress)
        webView.publisher(for: \.isLoading).assign(to: &$isLoading)
        webView.publisher(for: \.canGoBack).assign(to: &$canGoBack)
        webView.publisher(for: \.canGoForward).assign(to: &$canGoForward)
    }

    var displayTitle: String {
        if showsNewTab { return "Nuova scheda" }
        if !title.isEmpty { return title }
        return url?.host() ?? "Caricamento…"
    }

    func load(_ url: URL) {
        showsNewTab = false
        errorMessage = nil
        webView.load(URLRequest(url: url))
    }

    func goBack() {
        if webView.canGoBack {
            webView.goBack()
        } else if !showsNewTab {
            webView.stopLoading()
            showsNewTab = true
        }
    }

    func goForward() {
        if showsNewTab, webView.url != nil {
            showsNewTab = false
        } else {
            webView.goForward()
        }
    }

    /// HTTPS forzato: "http://" diventa "https://".
    private func httpsVersion(of url: URL) -> URL? {
        guard url.scheme == "http", let host = url.host(), host != "localhost", host != "127.0.0.1" else { return nil }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return components?.url
    }
}

extension BrowserTab: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else { return .allow }

        if let secure = httpsVersion(of: url) {
            webView.load(URLRequest(url: secure))
            return .cancel
        }
        if ["https", "about", "blob", "data"].contains(scheme) {
            return .allow
        }
        // tel:, mailto:, link all'App Store, ecc. → li apre iOS.
        if navigationAction.navigationType == .linkActivated, UIApplication.shared.canOpenURL(url) {
            _ = await UIApplication.shared.open(url)
        }
        return .cancel
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        blockedOnPage = 0
        errorMessage = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showError(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showError(error)
    }

    private func showError(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled { return }
        if nsError.domain == "WebKitErrorDomain", nsError.code == 102 { return } // download/frame interrotto
        errorMessage = error.localizedDescription
    }
}

extension BrowserTab: WKUIDelegate {
    /// I link che vorrebbero aprire una nuova finestra si aprono nella scheda attuale.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
