import XCTest
@testable import CrossPromoSDK

final class AppSelectorTests: XCTestCase {

    private func makeApp(
        appId: String,
        platforms: [String] = ["android", "ios"],
        enabled: Bool = true,
        priority: Int = 10
    ) -> PromoApp {
        PromoApp(
            appId: appId,
            appName: appId,
            platforms: platforms,
            enabled: enabled,
            priority: priority
        )
    }

    func testFilterAppsExcludesCurrentApp() {
        let apps = [makeApp(appId: "app1"), makeApp(appId: "app2"), makeApp(appId: "app3")]
        let filtered = AppSelector.filterApps(apps, currentAppId: "app2")
        XCTAssertEqual(filtered.count, 2)
        XCTAssertFalse(filtered.contains(where: { $0.appId == "app2" }))
    }

    func testFilterAppsExcludesWrongPlatform() {
        let apps = [
            makeApp(appId: "app1", platforms: ["android"]),
            makeApp(appId: "app2", platforms: ["ios"]),
            makeApp(appId: "app3", platforms: ["android", "ios"]),
        ]
        let filtered = AppSelector.filterApps(apps, currentAppId: "none", platform: "ios")
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains(where: { $0.appId == "app2" }))
        XCTAssertTrue(filtered.contains(where: { $0.appId == "app3" }))
    }

    func testFilterAppsExcludesDisabledApps() {
        let apps = [
            makeApp(appId: "app1", enabled: true),
            makeApp(appId: "app2", enabled: false),
        ]
        let filtered = AppSelector.filterApps(apps, currentAppId: "none")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.appId, "app1")
    }

    func testSelectWeightedRandomReturnsNilForEmpty() {
        XCTAssertNil(AppSelector.selectWeightedRandom([]))
    }

    func testSelectWeightedRandomReturnsSingleApp() {
        let app = makeApp(appId: "app1")
        XCTAssertEqual(AppSelector.selectWeightedRandom([app])?.appId, "app1")
    }

    func testSelectWeightedRandomRespectsWeights() {
        let high = makeApp(appId: "high", priority: 100)
        let low = makeApp(appId: "low", priority: 1)
        let apps = [high, low]

        var highCount = 0
        for _ in 0..<1000 {
            if AppSelector.selectWeightedRandom(apps)?.appId == "high" {
                highCount += 1
            }
        }
        XCTAssertGreaterThan(highCount, 900, "High priority app should be selected >90% of the time")
    }
}
