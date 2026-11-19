import Foundation
import WebKit

/// Il blocco di tracker, pubblicità e banner dei cookie.
/// Su iPhone uBlock Origin non può girare, quindi usiamo il blocco contenuti di WebKit.
enum Blocker {
    /// Domini di tracker e pubblicità bloccati quando un sito li carica da fuori.
    static let trackerDomains: [String] = [
        // Google
        "google-analytics.com", "googletagmanager.com", "googletagservices.com",
        "doubleclick.net", "googlesyndication.com", "googleadservices.com",
        "adservice.google.com", "imasdk.googleapis.com",
        // Meta, Microsoft, X, TikTok, LinkedIn, Pinterest, Snap
        "connect.facebook.net", "facebook.net", "an.facebook.com",
        "clarity.ms", "bat.bing.com", "ads-twitter.com", "analytics.twitter.com",
        "analytics.tiktok.com", "ads.linkedin.com", "px.ads.linkedin.com", "snap.licdn.com",
        "ct.pinterest.com", "sc-static.net",
        // Pubblicità
        "amazon-adsystem.com", "adnxs.com", "criteo.com", "criteo.net", "taboola.com",
        "outbrain.com", "pubmatic.com", "rubiconproject.com", "openx.net", "casalemedia.com",
        "smartadserver.com", "teads.tv", "adform.net", "yieldlab.net", "3lift.com",
        "sharethrough.com", "media.net", "moatads.com", "adsrvr.org", "bidswitch.net",
        "quantserve.com", "quantcount.com", "zemanta.com", "seedtag.com", "richaudience.com",
        "adkernel.com", "onetag-sys.com", "sonobi.com", "lijit.com", "gumgum.com",
        // Statistiche e "heatmap"
        "hotjar.com", "hotjar.io", "mouseflow.com", "fullstory.com", "crazyegg.com",
        "luckyorange.com", "mixpanel.com", "segment.com", "segment.io", "amplitude.com",
        "heap.io", "heapanalytics.com", "newrelic.com", "nr-data.net", "scorecardresearch.com",
        "chartbeat.com", "chartbeat.net", "parsely.com", "comscore.com", "kissmetrics.com",
        "yandex.ru/metrika", "mc.yandex.ru", "statcounter.com",
        // Italiani
        "webtrekk.net", "audienceserver.com", "nielsen.com", "imrworldwide.com",
        "shinystat.com", "contactlab.it", "triboo.it", "4wnet.com", "mookie1.com",
    ]

    /// Banner dei cookie più diffusi (anche quelli italiani come iubenda): vengono nascosti.
    static let cookieBannerSelectors: [String] = [
        "#onetrust-banner-sdk", "#onetrust-consent-sdk", "#CybotCookiebotDialog",
        "#iubenda-cs-banner", ".iubenda-cs-container", "#didomi-host", ".qc-cmp2-container",
        ".fc-consent-root", "#cookie-law-info-bar", "#cmplz-cookiebanner-container",
        ".cc-window", "#usercentrics-root", "#truste-consent-track", ".osano-cm-window",
        "#cookiescript_injected", ".cky-consent-container", "#qc-cmp2-ui",
    ]

    private static var rulesJSON: String {
        var rules: [[String: Any]] = trackerDomains.map { domain in
            let host = domain.split(separator: "/").first.map(String.init) ?? domain
            let escaped = NSRegularExpression.escapedPattern(for: host)
            return [
                "trigger": [
                    "url-filter": "^[^:]+://+([^:/]+\\.)?" + escaped + "[:/]",
                    "load-type": ["third-party"],
                ],
                "action": ["type": "block"],
            ]
        }
        rules.append([
            "trigger": ["url-filter": ".*"],
            "action": ["type": "css-display-none", "selector": cookieBannerSelectors.joined(separator: ", ")],
        ])
        let data = (try? JSONSerialization.data(withJSONObject: rules)) ?? Data("[]".utf8)
        return String(decoding: data, as: UTF8.self)
    }

    @MainActor
    static func compile() async -> WKContentRuleList? {
        try? await WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "freeowl-blocker-v1",
            encodedContentRuleList: rulesJSON
        )
    }

    /// Script che conta i tracker presenti nella pagina (che il blocco ha già fermato)
    /// e li manda all'app, così il gufo può dirti quanti ne ha bloccati.
    static var counterScript: String {
        let hosts = trackerDomains.map { $0.split(separator: "/").first.map(String.init) ?? $0 }
        let list = (try? JSONSerialization.data(withJSONObject: hosts)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
        return """
        (function () {
          if (window.__owlCounter) { return; }
          window.__owlCounter = true;
          var domains = \(list);
          var seen = new Set();
          var page = location.hostname;
          function matches(host, d) { return host === d || host.endsWith('.' + d); }
          function tracker(host) {
            if (!host) { return false; }
            for (var i = 0; i < domains.length; i++) {
              if (matches(host, domains[i]) && !matches(page, domains[i])) { return true; }
            }
            return false;
          }
          function scan() {
            var found = 0;
            document.querySelectorAll('script[src], img[src], iframe[src], link[href]').forEach(function (el) {
              var u = el.src || el.href;
              if (!u || seen.has(u)) { return; }
              var host;
              try { host = new URL(u, location.href).hostname; } catch (e) { return; }
              if (tracker(host)) { seen.add(u); found++; }
            });
            if (found > 0) { window.webkit.messageHandlers.owlTrackers.postMessage(found); }
          }
          var timer = null;
          function later() { if (timer) { return; } timer = setTimeout(function () { timer = null; scan(); }, 600); }
          scan();
          new MutationObserver(later).observe(document.documentElement, { childList: true, subtree: true });
        })();
        """
    }

    /// Modalità Notte: come su desktop, scurisce i siti chiari e lascia stare foto, video e siti già scuri.
    static let nightScript = """
    window.__owlNight = function (on) {
      var id = 'freeowl-night';
      var style = document.getElementById(id);
      if (!on) { if (style) { style.remove(); } return; }
      if (style) { return; }
      function isDark(color) {
        var m = color.match(/\\d+(\\.\\d+)?/g);
        if (!m || (m.length === 4 && Number(m[3]) === 0)) { return null; }
        return (0.2126 * m[0] + 0.7152 * m[1] + 0.0722 * m[2]) / 255 < 0.4;
      }
      if (document.body) {
        var dark = isDark(getComputedStyle(document.body).backgroundColor);
        if (dark === null) { dark = isDark(getComputedStyle(document.documentElement).backgroundColor); }
        if (dark) { return; }
      }
      style = document.createElement('style');
      style.id = id;
      style.textContent = 'html{filter:invert(1) hue-rotate(180deg)!important;background-color:#fff!important}' +
        'img,video,picture,canvas,iframe,embed,object,svg image,[style*="background-image"]{filter:invert(1) hue-rotate(180deg)!important}';
      (document.head || document.documentElement).appendChild(style);
    };
    """
}
