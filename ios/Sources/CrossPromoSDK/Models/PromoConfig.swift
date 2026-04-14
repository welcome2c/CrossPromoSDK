import Foundation

public struct PromoConfig: Codable {
    public let enabled: Bool
    public let selectionMode: String
    public let minAppOpenCount: Int
    public let popupTitle: String

    public init(
        enabled: Bool = true,
        selectionMode: String = "weighted_random",
        minAppOpenCount: Int = 3,
        popupTitle: String = "개발자의 다른 앱"
    ) {
        self.enabled = enabled
        self.selectionMode = selectionMode
        self.minAppOpenCount = minAppOpenCount
        self.popupTitle = popupTitle
    }
}
