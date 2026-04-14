import Foundation
import FirebaseFirestore

final class FirestoreService {

    private let db = Firestore.firestore()

    func fetchApps() async throws -> [PromoApp] {
        let snapshot = try await db.collection("cross_promo_apps").getDocuments()
        return snapshot.documents.compactMap { doc -> PromoApp? in
            let data = doc.data()
            guard let appId = data["appId"] as? String else { return nil }

            return PromoApp(
                appId: appId,
                appName: data["appName"] as? String ?? "",
                shortDescription: data["shortDescription"] as? String ?? "",
                iconUrl: data["iconUrl"] as? String ?? "",
                platforms: data["platforms"] as? [String] ?? [],
                storeLinks: data["storeLinks"] as? [String: String] ?? [:],
                iosAppStoreId: data["iosAppStoreId"] as? String ?? "",
                priority: data["priority"] as? Int ?? 10,
                enabled: data["enabled"] as? Bool ?? true
            )
        }
    }

    func fetchConfig() async throws -> PromoConfig {
        let doc = try await db.collection("cross_promo_config").document("settings").getDocument()

        guard doc.exists, let data = doc.data() else {
            return PromoConfig()
        }

        return PromoConfig(
            enabled: data["enabled"] as? Bool ?? true,
            selectionMode: data["selectionMode"] as? String ?? "weighted_random",
            minAppOpenCount: data["minAppOpenCount"] as? Int ?? 3,
            popupTitle: data["popupTitle"] as? String ?? "개발자의 다른 앱"
        )
    }
}
