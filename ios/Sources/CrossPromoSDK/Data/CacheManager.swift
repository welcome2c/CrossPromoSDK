import Foundation

final class CacheManager {

    private let defaults = UserDefaults(suiteName: "kr.dev.hoony.crosspromo.cache")!

    private let appsKey = "cached_apps"
    private let configKey = "cached_config"
    private let cacheTimeKey = "cache_timestamp"
    private let cacheTTL: TimeInterval = 3600 // 1 hour

    var isCacheValid: Bool {
        let cachedTime = defaults.double(forKey: cacheTimeKey)
        guard cachedTime > 0 else { return false }
        return Date().timeIntervalSince1970 - cachedTime < cacheTTL
    }

    func saveApps(_ apps: [PromoApp]) {
        if let data = try? JSONEncoder().encode(apps) {
            defaults.set(data, forKey: appsKey)
            defaults.set(Date().timeIntervalSince1970, forKey: cacheTimeKey)
        }
    }

    func loadApps() -> [PromoApp] {
        guard let data = defaults.data(forKey: appsKey),
              let apps = try? JSONDecoder().decode([PromoApp].self, from: data) else {
            return []
        }
        return apps
    }

    func saveConfig(_ config: PromoConfig) {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: configKey)
        }
    }

    func loadConfig() -> PromoConfig? {
        guard let data = defaults.data(forKey: configKey),
              let config = try? JSONDecoder().decode(PromoConfig.self, from: data) else {
            return nil
        }
        return config
    }

    func clearCache() {
        defaults.removeObject(forKey: appsKey)
        defaults.removeObject(forKey: configKey)
        defaults.removeObject(forKey: cacheTimeKey)
    }
}
