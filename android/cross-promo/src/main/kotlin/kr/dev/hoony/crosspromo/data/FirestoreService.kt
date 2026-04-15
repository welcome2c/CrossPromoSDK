package kr.dev.hoony.crosspromo.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kr.dev.hoony.crosspromo.model.PromoApp
import kr.dev.hoony.crosspromo.model.PromoConfig
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

internal class FirestoreService(private val projectId: String) {

    private val baseUrl =
        "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents"

    suspend fun fetchApps(): List<PromoApp> = withContext(Dispatchers.IO) {
        val json = httpGet("$baseUrl/cross_promo_apps")
        val documents = json.optJSONArray("documents") ?: return@withContext emptyList()

        (0 until documents.length()).mapNotNull { i ->
            try {
                val doc = documents.getJSONObject(i)
                val fields = doc.getJSONObject("fields")
                parsePromoApp(fields)
            } catch (e: Exception) {
                null
            }
        }
    }

    suspend fun fetchConfig(): PromoConfig = withContext(Dispatchers.IO) {
        try {
            val json = httpGet("$baseUrl/cross_promo_config/settings")
            val fields = json.getJSONObject("fields")
            PromoConfig(
                enabled = fields.optJSONObject("enabled")?.optBoolean("booleanValue") ?: true,
                selectionMode = fields.optJSONObject("selectionMode")?.optString("stringValue")
                    ?: "weighted_random",
                minAppOpenCount = fields.optJSONObject("minAppOpenCount")
                    ?.optString("integerValue")?.toIntOrNull() ?: 3,
                popupTitle = fields.optJSONObject("popupTitle")?.optString("stringValue")
                    ?: "개발자의 다른 앱",
            )
        } catch (e: Exception) {
            PromoConfig()
        }
    }

    private fun parsePromoApp(fields: JSONObject): PromoApp? {
        val appId = fields.optJSONObject("appId")?.optString("stringValue") ?: return null

        val platforms = mutableListOf<String>()
        fields.optJSONObject("platforms")
            ?.optJSONObject("arrayValue")
            ?.optJSONArray("values")
            ?.let { arr ->
                for (j in 0 until arr.length()) {
                    arr.getJSONObject(j).optString("stringValue")?.let { platforms.add(it) }
                }
            }

        val storeLinks = mutableMapOf<String, String>()
        fields.optJSONObject("storeLinks")
            ?.optJSONObject("mapValue")
            ?.optJSONObject("fields")
            ?.let { linksFields ->
                linksFields.keys().forEach { key ->
                    linksFields.optJSONObject(key)?.optString("stringValue")?.let {
                        storeLinks[key] = it
                    }
                }
            }

        return PromoApp(
            appId = appId,
            appName = fields.optJSONObject("appName")?.optString("stringValue") ?: "",
            shortDescription = fields.optJSONObject("shortDescription")?.optString("stringValue")
                ?: "",
            iconUrl = fields.optJSONObject("iconUrl")?.optString("stringValue") ?: "",
            platforms = platforms,
            storeLinks = storeLinks,
            iosAppStoreId = fields.optJSONObject("iosAppStoreId")?.optString("stringValue") ?: "",
            priority = fields.optJSONObject("priority")?.optString("integerValue")?.toIntOrNull()
                ?: 10,
            enabled = fields.optJSONObject("enabled")?.optBoolean("booleanValue") ?: true,
        )
    }

    private fun httpGet(urlString: String): JSONObject {
        val url = URL(urlString)
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.connectTimeout = 10_000
        connection.readTimeout = 10_000

        return try {
            val responseCode = connection.responseCode
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val body = connection.inputStream.bufferedReader().readText()
                JSONObject(body)
            } else {
                throw Exception("HTTP $responseCode")
            }
        } finally {
            connection.disconnect()
        }
    }
}
