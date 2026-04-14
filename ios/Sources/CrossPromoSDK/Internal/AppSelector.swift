import Foundation

enum AppSelector {

    /// Filter apps for the current platform, excluding the current app and disabled apps.
    static func filterApps(
        _ apps: [PromoApp],
        currentAppId: String,
        platform: String = "ios"
    ) -> [PromoApp] {
        apps.filter { app in
            app.enabled &&
            app.appId != currentAppId &&
            app.platforms.contains(platform)
        }
    }

    /// Select an app using weighted random selection based on priority.
    static func selectWeightedRandom(_ apps: [PromoApp]) -> PromoApp? {
        guard !apps.isEmpty else { return nil }
        guard apps.count > 1 else { return apps.first }

        let totalWeight = apps.reduce(0) { $0 + max($1.priority, 1) }
        var random = Int.random(in: 0..<totalWeight)

        for app in apps {
            random -= max(app.priority, 1)
            if random < 0 { return app }
        }

        return apps.last
    }
}
