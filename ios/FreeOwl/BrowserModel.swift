import SwiftUI
import WebKit

/// Il cervello del browser: schede, impostazioni, blocco tracker, Vola via.
@MainActor
final class BrowserModel: ObservableObject {
    @Published private(set) var tabs: [BrowserTab] = []
    @Published var currentID: UUID?

    @Published var engine: SearchEngine {
        didSet { UserDefaults.standard.set(engine.rawValue, forKey: "engine") }
    }
    @Published var nightMode: Bool {
        didSet {
            UserDefaults.standard.set(nightMode, forKey: "nightMode")
            applyNightMode()
        }
    }

    let stats = TrackerStats()
    private let contentController = WKUserContentController()
    private var messageHandler: TrackerMessageHandler?

    init() {
        let defaults = UserDefaults.standard
        engine = SearchEngine(rawValue: defaults.string(forKey: "engine") ?? "") ?? .duckduckgo
        nightMode = defaults.bool(forKey: "nightMode")

        let handler = TrackerMessageHandler(model: self)
        contentController.add(handler, name: "owlTrackers")
        messageHandler = handler
        installScripts()
        let firstTab = newTab()

        Task {
            if let rules = await Blocker.compile() {
                contentController.add(rules)
            }
            #if DEBUG
            // Solo per i test: `-startURL https://…` all'avvio apre subito quel sito.
            if let start = defaults.string(forKey: "startURL") {
                open(start, in: firstTab)
            }
            #endif
        }
    }

    var current: BrowserTab? {
        tabs.first { $0.id == currentID }
    }

    // MARK: Schede

    @discardableResult
    func newTab(url: URL? = nil) -> BrowserTab {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        let tab = BrowserTab(configuration: configuration)
        tabs.append(tab)
        currentID = tab.id
        if let url { tab.load(url) }
        return tab
    }

    func select(_ tab: BrowserTab) {
        currentID = tab.id
    }

    func close(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tab.webView.stopLoading()
        tabs.remove(at: index)
        if tabs.isEmpty {
            newTab()
        } else if currentID == tab.id {
            currentID = tabs[min(index, tabs.count - 1)].id
        }
    }

    // MARK: Ricerca

    /// Capisce se hai scritto un indirizzo o una ricerca.
    func destination(for input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if text.contains("://"), let url = URL(string: text), url.scheme != nil {
            return url
        }
        if !text.contains(" "), text.contains("."), !text.hasSuffix("."),
           let url = URL(string: "https://" + text), url.host() != nil {
            return url
        }
        return engine.url(for: text)
    }

    func open(_ input: String, in tab: BrowserTab? = nil) {
        guard let url = destination(for: input) else { return }
        (tab ?? current ?? newTab()).load(url)
    }

    // MARK: Vola via 🪶

    /// Cancella cookie, cronologia, cache e chiude tutte le schede.
    func flyAway() async {
        for tab in tabs { tab.webView.stopLoading() }
        tabs.removeAll()
        currentID = nil
        await WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        )
        URLCache.shared.removeAllCachedResponses()
        newTab()
    }

    // MARK: Script nelle pagine

    private func installScripts() {
        contentController.removeAllUserScripts()
        contentController.addUserScript(WKUserScript(
            source: Blocker.counterScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        contentController.addUserScript(WKUserScript(
            source: Blocker.nightScript + "\nwindow.__owlNight(\(nightMode));",
            injectionTime: .atDocumentEnd, forMainFrameOnly: true))
    }

    private func applyNightMode() {
        installScripts()
        for tab in tabs where !tab.showsNewTab {
            tab.webView.evaluateJavaScript(Blocker.nightScript + "\nwindow.__owlNight(\(nightMode));")
        }
    }

    fileprivate func trackersBlocked(_ count: Int, in webView: WKWebView?) {
        stats.add(count)
        if let tab = tabs.first(where: { $0.webView === webView }) {
            tab.blockedOnPage += count
        }
    }
}

/// Riceve dalle pagine il numero di tracker trovati. È separato dal modello per non creare cicli di memoria.
private final class TrackerMessageHandler: NSObject, WKScriptMessageHandler {
    weak var model: BrowserModel?

    init(model: BrowserModel) {
        self.model = model
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let count = message.body as? Int else { return }
        let webView = message.webView
        MainActor.assumeIsolated {
            model?.trackersBlocked(count, in: webView)
        }
    }
}
