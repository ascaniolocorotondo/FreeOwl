import SwiftUI

@main
struct FreeOwlApp: App {
    @StateObject private var browser = BrowserModel()

    var body: some Scene {
        WindowGroup {
            BrowserView()
                .environmentObject(browser)
                .environmentObject(browser.stats)
                .preferredColorScheme(.dark)
        }
    }
}

/// I colori di Free Owl, gli stessi della versione desktop.
enum Owl {
    static let plum = Color(red: 0x4e / 255, green: 0x1a / 255, blue: 0x3d / 255)
    static let plumDark = Color(red: 0x3a / 255, green: 0x12 / 255, blue: 0x30 / 255)
    static let plumLight = Color(red: 0x6a / 255, green: 0x27 / 255, blue: 0x54 / 255)
    static let cream = Color(red: 0xf5 / 255, green: 0xe2 / 255, blue: 0xaa / 255)
    static let creamSoft = cream.opacity(0.75)
    static let orange = Color(red: 0xe8 / 255, green: 0xa3 / 255, blue: 0x3d / 255)
}
