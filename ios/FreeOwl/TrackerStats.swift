import Foundation

/// Conta i tracker bloccati dal gufo: in totale e oggi.
@MainActor
final class TrackerStats: ObservableObject {
    @Published private(set) var total: Int
    @Published private(set) var today: Int
    private var day: String

    init() {
        let defaults = UserDefaults.standard
        let now = Self.dayString()
        total = defaults.integer(forKey: "stats.total")
        today = defaults.string(forKey: "stats.day") == now ? defaults.integer(forKey: "stats.today") : 0
        day = now
    }

    func add(_ count: Int) {
        guard count > 0 else { return }
        let now = Self.dayString()
        if now != day {
            day = now
            today = 0
        }
        total += count
        today += count
        let defaults = UserDefaults.standard
        defaults.set(total, forKey: "stats.total")
        defaults.set(today, forKey: "stats.today")
        defaults.set(day, forKey: "stats.day")
    }

    private static func dayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
