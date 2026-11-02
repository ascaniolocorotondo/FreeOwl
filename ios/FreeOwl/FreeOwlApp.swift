import SwiftUI
import WebKit

// Free Owl per iPhone: WebKit + blocco di pubblicità e tracker + link puliti.

let plum = Color(red: 0x4e / 255, green: 0x1a / 255, blue: 0x3d / 255)
let cream = Color(red: 0xf5 / 255, green: 0xe2 / 255, blue: 0xaa / 255)
let amber = Color(red: 0xe8 / 255, green: 0xa3 / 255, blue: 0x3d / 255)

let homePage = "https://duckduckgo.com/?kl=it-it"

@main
struct FreeOwlApp: App {
    var body: some Scene {
        WindowGroup { BrowserView() }
    }
}

final class Browser: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    @Published var address = ""
    @Published var progress = 1.0
    @Published var canGoBack = false
    @Published var canGoForward = false
    private var observers: [NSKeyValueObservation] = []

    override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        observers = [
            webView.observe(\.url) { [weak self] wv, _ in self?.address = wv.url?.absoluteString ?? "" },
            webView.observe(\.estimatedProgress) { [weak self] wv, _ in self?.progress = wv.estimatedProgress },
            webView.observe(\.canGoBack) { [weak self] wv, _ in self?.canGoBack = wv.canGoBack },
            webView.observe(\.canGoForward) { [weak self] wv, _ in self?.canGoForward = wv.canGoForward },
        ]
        // Prima carichiamo le regole di blocco, poi la pagina: cosi' anche la prima e' protetta
        loadBlocklist { [weak self] in self?.open(homePage) }
    }

    private func loadBlocklist(then done: @escaping () -> Void) {
        guard let url = Bundle.main.url(forResource: "blocklist", withExtension: "json"),
              let json = try? String(contentsOf: url) else { return done() }
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "freeowl", encodedContentRuleList: json) { [weak self] list, _ in
            if let list { self?.webView.configuration.userContentController.add(list) }
            done()
        }
    }

    /// Apre un indirizzo, oppure cerca il testo su DuckDuckGo.
    func open(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        var url: URL?
        if text.contains("://") {
            url = URL(string: text)
        } else if text.contains("."), !text.contains(" ") {
            url = URL(string: "https://" + text)
        }
        if url == nil {
            var c = URLComponents(string: "https://duckduckgo.com/")!
            c.queryItems = [URLQueryItem(name: "q", value: text), URLQueryItem(name: "kl", value: "it-it")]
            url = c.url
        }
        if let url { webView.load(URLRequest(url: url)) }
    }

    /// "Vola via": cancella cookie, cronologia e cache.
    func flyAway() {
        let store = WKWebsiteDataStore.default()
        store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { [weak self] in
            self?.open(homePage)
        }
    }

    /// Toglie dai link i parametri che servono solo a tracciarti (utm_, fbclid, ...).
    static func stripTracking(_ url: URL) -> URL? {
        guard var c = URLComponents(url: url, resolvingAgainstBaseURL: false), let items = c.queryItems else { return nil }
        let junk: Set<String> = ["fbclid", "gclid", "dclid", "msclkid", "igshid", "mc_eid", "yclid", "twclid", "ttclid"]
        let kept = items.filter { !$0.name.hasPrefix("utm_") && !junk.contains($0.name) }
        guard kept.count != items.count else { return nil }
        c.queryItems = kept.isEmpty ? nil : kept
        return c.url
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { return decisionHandler(.allow) }
        // tel:, mailto:, link dell'App Store... li apre l'iPhone
        if let scheme = url.scheme, !["http", "https", "about", "data", "blob"].contains(scheme) {
            UIApplication.shared.open(url)
            return decisionHandler(.cancel)
        }
        if action.targetFrame?.isMainFrame == true, let clean = Self.stripTracking(url) {
            decisionHandler(.cancel)
            webView.load(URLRequest(url: clean))
            return
        }
        decisionHandler(.allow)
    }

    // I link "apri in una nuova finestra" si aprono qui
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.targetFrame == nil { webView.load(action.request) }
        return nil
    }
}

struct WebView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct BrowserView: View {
    @StateObject private var browser = Browser()
    @State private var text = ""
    @State private var confirmFlyAway = false
    @FocusState private var editing: Bool

    var body: some View {
        VStack(spacing: 0) {
            WebView(webView: browser.webView)

            ProgressView(value: browser.progress)
                .tint(amber)
                .opacity(browser.progress < 1 ? 1 : 0)

            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(plum.opacity(0.6))
                    TextField("Cerca o scrivi un indirizzo", text: $text)
                        .focused($editing)
                        .keyboardType(.webSearch)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit { browser.open(text); editing = false }
                        .foregroundColor(plum)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(cream, in: Capsule())

                HStack {
                    button("chevron.left", enabled: browser.canGoBack) { browser.webView.goBack() }
                    button("chevron.right", enabled: browser.canGoForward) { browser.webView.goForward() }
                    button("arrow.clockwise") { browser.webView.reload() }
                    if let url = URL(string: browser.address), !browser.address.isEmpty {
                        ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                            .frame(maxWidth: .infinity)
                    }
                    button("wind") { confirmFlyAway = true }
                }
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(cream)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .background(plum)
        }
        .background(plum)
        .onChange(of: browser.address) { new in if !editing { text = new } }
        .onChange(of: editing) { on in if !on { text = browser.address } }
        .confirmationDialog("Vola via?", isPresented: $confirmFlyAway, titleVisibility: .visible) {
            Button("Cancella cookie e cronologia", role: .destructive) { browser.flyAway() }
        } message: {
            Text("Il gufo cancella tutto quello che i siti hanno salvato su questo iPhone.")
        }
    }

    private func button(_ icon: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon) }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.35)
            .frame(maxWidth: .infinity)
    }
}
