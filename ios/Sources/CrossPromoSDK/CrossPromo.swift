import SwiftUI
import StoreKit

public final class CrossPromo: ObservableObject {

    public static let shared = CrossPromo()

    private var currentAppId: String = ""
    private var firestoreService: FirestoreService!
    private let cacheManager = CacheManager()
    private let frequencyManager = FrequencyManager()

    private var apps: [PromoApp] = []
    @Published private var config = PromoConfig()
    private var isDataLoaded = false

    private init() {}

    // MARK: - Public API

    /// Initialize the SDK. Call this in your App's init() or on appear.
    ///
    /// - Parameters:
    ///   - currentAppId: The bundle identifier of the host app
    ///   - firebaseProjectId: The Firebase project ID for CrossPromo Firestore (default: "crosspromosdk")
    public func initialize(currentAppId: String, firebaseProjectId: String = "crosspromosdk") {
        self.currentAppId = currentAppId
        self.firestoreService = FirestoreService(projectId: firebaseProjectId)
        frequencyManager.incrementAppOpenCount()
        frequencyManager.resetSession()

        Task {
            await loadData()
        }
    }

    /// Check if a promo can be shown right now.
    public func canShow() -> Bool {
        guard isDataLoaded, config.enabled, !apps.isEmpty else { return false }
        return frequencyManager.canShow(minAppOpenCount: config.minAppOpenCount)
    }

    /// Select an app to promote. Returns nil if no app is available.
    public func selectApp() -> PromoApp? {
        guard canShow() else { return nil }
        return AppSelector.selectWeightedRandom(apps)
    }

    /// Record that the promo was dismissed for today.
    public func dismissForToday() {
        frequencyManager.dismissForToday()
    }

    /// Record that the promo was shown in this session.
    public func markShown() {
        frequencyManager.markSessionShown()
    }

    /// Get the popup title from config.
    public var popupTitle: String { config.popupTitle }

    /// Open the App Store page for the given app.
    public func openAppStore(for app: PromoApp) {
        if let appStoreId = Int(app.iosAppStoreId), appStoreId > 0 {
            openStoreProduct(appStoreId: appStoreId)
        } else if let urlString = app.storeLinks["ios"],
                  let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Private

    private func loadData() async {
        if cacheManager.isCacheValid {
            let cachedApps = cacheManager.loadApps()
            if let cachedConfig = cacheManager.loadConfig(), !cachedApps.isEmpty {
                config = cachedConfig
                apps = AppSelector.filterApps(cachedApps, currentAppId: currentAppId)
                isDataLoaded = true
                return
            }
        }

        do {
            let allApps = try await firestoreService.fetchApps()
            let fetchedConfig = try await firestoreService.fetchConfig()

            cacheManager.saveApps(allApps)
            cacheManager.saveConfig(fetchedConfig)

            await MainActor.run {
                config = fetchedConfig
                apps = AppSelector.filterApps(allApps, currentAppId: currentAppId)
                isDataLoaded = true
            }
        } catch {
            let cachedApps = cacheManager.loadApps()
            let cachedConfig = cacheManager.loadConfig() ?? PromoConfig()
            await MainActor.run {
                config = cachedConfig
                apps = AppSelector.filterApps(cachedApps, currentAppId: currentAppId)
                isDataLoaded = !apps.isEmpty
            }
        }
    }

    private func openStoreProduct(appStoreId: Int) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let rootVC = scene.windows.first?.rootViewController else {
            return
        }

        let storeVC = SKStoreProductViewController()
        storeVC.loadProduct(withParameters: [
            SKStoreProductParameterITunesItemIdentifier: NSNumber(value: appStoreId)
        ])

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        topVC.present(storeVC, animated: true)
    }
}

// MARK: - SwiftUI View Modifier

public extension View {

    /// Show the cross-promotion popup if conditions are met.
    ///
    /// Usage:
    /// ```swift
    /// ContentView()
    ///     .crossPromoPopup()
    /// ```
    func crossPromoPopup(delaySeconds: Double = 2.0) -> some View {
        modifier(CrossPromoModifier(delaySeconds: delaySeconds))
    }
}

struct CrossPromoModifier: ViewModifier {
    let delaySeconds: Double

    @State private var showPopup = false
    @State private var selectedApp: PromoApp?

    func body(content: Content) -> some View {
        content
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) {
                    if CrossPromo.shared.canShow() {
                        selectedApp = CrossPromo.shared.selectApp()
                        if selectedApp != nil {
                            showPopup = true
                        }
                    }
                }
            }
            .overlay {
                if showPopup, let app = selectedApp {
                    CrossPromoView(
                        app: app,
                        title: CrossPromo.shared.popupTitle,
                        onInstall: {
                            CrossPromo.shared.openAppStore(for: app)
                            CrossPromo.shared.markShown()
                            showPopup = false
                        },
                        onDismissToday: {
                            CrossPromo.shared.dismissForToday()
                            showPopup = false
                        },
                        onClose: {
                            CrossPromo.shared.markShown()
                            showPopup = false
                        }
                    )
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showPopup)
                }
            }
    }
}
