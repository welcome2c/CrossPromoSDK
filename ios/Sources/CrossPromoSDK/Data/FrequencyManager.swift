import Foundation

final class FrequencyManager {

    private let defaults = UserDefaults(suiteName: "kr.dev.hoony.crosspromo.frequency")!

    private let dismissDateKey = "dismiss_date"
    private let sessionShownKey = "session_shown"
    private let appOpenCountKey = "app_open_count"

    func incrementAppOpenCount() {
        let current = appOpenCount
        defaults.set(current + 1, forKey: appOpenCountKey)
    }

    var appOpenCount: Int {
        defaults.integer(forKey: appOpenCountKey)
    }

    var isDismissedToday: Bool {
        guard let dismissDate = defaults.string(forKey: dismissDateKey) else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return dismissDate == formatter.string(from: Date())
    }

    func dismissForToday() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        defaults.set(formatter.string(from: Date()), forKey: dismissDateKey)
    }

    var isSessionShown: Bool {
        defaults.bool(forKey: sessionShownKey)
    }

    func markSessionShown() {
        defaults.set(true, forKey: sessionShownKey)
    }

    func resetSession() {
        defaults.set(false, forKey: sessionShownKey)
    }

    func canShow(minAppOpenCount: Int) -> Bool {
        if appOpenCount < minAppOpenCount { return false }
        if isDismissedToday { return false }
        if isSessionShown { return false }
        return true
    }
}
