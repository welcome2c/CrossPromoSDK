import Foundation

public struct PromoApp: Codable, Identifiable {
    public var id: String { appId }

    public let appId: String
    public let appName: String
    public let shortDescription: String
    public let iconUrl: String
    public let platforms: [String]
    public let storeLinks: [String: String]
    public let iosAppStoreId: String
    public let priority: Int
    public let enabled: Bool

    public init(
        appId: String = "",
        appName: String = "",
        shortDescription: String = "",
        iconUrl: String = "",
        platforms: [String] = [],
        storeLinks: [String: String] = [:],
        iosAppStoreId: String = "",
        priority: Int = 10,
        enabled: Bool = true
    ) {
        self.appId = appId
        self.appName = appName
        self.shortDescription = shortDescription
        self.iconUrl = iconUrl
        self.platforms = platforms
        self.storeLinks = storeLinks
        self.iosAppStoreId = iosAppStoreId
        self.priority = priority
        self.enabled = enabled
    }
}
