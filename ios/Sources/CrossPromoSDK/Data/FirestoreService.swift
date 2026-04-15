import Foundation

final class FirestoreService {

    private let baseUrl: String

    init(projectId: String = "crosspromosdk") {
        self.baseUrl = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents"
    }

    func fetchApps() async throws -> [PromoApp] {
        let data = try await httpGet("\(baseUrl)/cross_promo_apps")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let documents = json["documents"] as? [[String: Any]] else {
            return []
        }

        return documents.compactMap { doc -> PromoApp? in
            guard let fields = doc["fields"] as? [String: Any] else { return nil }
            return parsePromoApp(fields)
        }
    }

    func fetchConfig() async throws -> PromoConfig {
        let data = try await httpGet("\(baseUrl)/cross_promo_config/settings")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let fields = json["fields"] as? [String: Any] else {
            return PromoConfig()
        }

        return PromoConfig(
            enabled: boolValue(fields, "enabled") ?? true,
            selectionMode: stringValue(fields, "selectionMode") ?? "weighted_random",
            minAppOpenCount: intValue(fields, "minAppOpenCount") ?? 3,
            popupTitle: stringValue(fields, "popupTitle") ?? "개발자의 다른 앱"
        )
    }

    // MARK: - Firestore REST API Parsing

    private func parsePromoApp(_ fields: [String: Any]) -> PromoApp? {
        guard let appId = stringValue(fields, "appId") else { return nil }

        var platforms: [String] = []
        if let arrayValue = (fields["platforms"] as? [String: Any])?["arrayValue"] as? [String: Any],
           let values = arrayValue["values"] as? [[String: Any]] {
            platforms = values.compactMap { $0["stringValue"] as? String }
        }

        var storeLinks: [String: String] = [:]
        if let mapValue = (fields["storeLinks"] as? [String: Any])?["mapValue"] as? [String: Any],
           let linksFields = mapValue["fields"] as? [String: Any] {
            for (key, value) in linksFields {
                if let sv = (value as? [String: Any])?["stringValue"] as? String {
                    storeLinks[key] = sv
                }
            }
        }

        return PromoApp(
            appId: appId,
            appName: stringValue(fields, "appName") ?? "",
            shortDescription: stringValue(fields, "shortDescription") ?? "",
            iconUrl: stringValue(fields, "iconUrl") ?? "",
            platforms: platforms,
            storeLinks: storeLinks,
            iosAppStoreId: stringValue(fields, "iosAppStoreId") ?? "",
            priority: intValue(fields, "priority") ?? 10,
            enabled: boolValue(fields, "enabled") ?? true
        )
    }

    private func stringValue(_ fields: [String: Any], _ key: String) -> String? {
        (fields[key] as? [String: Any])?["stringValue"] as? String
    }

    private func intValue(_ fields: [String: Any], _ key: String) -> Int? {
        guard let str = (fields[key] as? [String: Any])?["integerValue"] as? String else { return nil }
        return Int(str)
    }

    private func boolValue(_ fields: [String: Any], _ key: String) -> Bool? {
        (fields[key] as? [String: Any])?["booleanValue"] as? Bool
    }

    // MARK: - HTTP

    private func httpGet(_ urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
