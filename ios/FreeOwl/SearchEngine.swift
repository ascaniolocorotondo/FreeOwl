import Foundation

/// Solo motori di ricerca che non ti tracciano, come su Free Owl desktop.
enum SearchEngine: String, CaseIterable, Identifiable {
    case duckduckgo, brave, startpage, mojeek, qwant

    var id: String { rawValue }

    var name: String {
        switch self {
        case .duckduckgo: return "DuckDuckGo"
        case .brave: return "Brave Search"
        case .startpage: return "Startpage"
        case .mojeek: return "Mojeek"
        case .qwant: return "Qwant"
        }
    }

    private var base: String {
        switch self {
        case .duckduckgo: return "https://duckduckgo.com/"
        case .brave: return "https://search.brave.com/search"
        case .startpage: return "https://www.startpage.com/do/search"
        case .mojeek: return "https://www.mojeek.com/search"
        case .qwant: return "https://www.qwant.com/"
        }
    }

    func url(for query: String) -> URL? {
        var components = URLComponents(string: base)
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }
}
