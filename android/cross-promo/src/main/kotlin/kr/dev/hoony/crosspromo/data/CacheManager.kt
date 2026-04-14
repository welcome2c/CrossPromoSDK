package kr.dev.hoony.crosspromo.data

import android.content.Context
import android.content.SharedPreferences
import kr.dev.hoony.crosspromo.model.PromoApp
import kr.dev.hoony.crosspromo.model.PromoConfig
import org.json.JSONArray
import org.json.JSONObject

internal class CacheManager(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("cross_promo_cache", Context.MODE_PRIVATE)

    companion object {
        private const val KEY_APPS = "cached_apps"
        private const val KEY_CONFIG = "cached_config"
        private const val KEY_CACHE_TIME = "cache_timestamp"
        private const val CACHE_TTL_MS = 60 * 60 * 1000L // 1 hour
    }

    fun isCacheValid(): Boolean {
        val cachedTime = prefs.getLong(KEY_CACHE_TIME, 0L)
        return System.currentTimeMillis() - cachedTime < CACHE_TTL_MS
    }

    fun saveApps(apps: List<PromoApp>) {
        val jsonArray = JSONArray()
        apps.forEach { app ->
            val obj = JSONObject().apply {
                put("appId", app.appId)
                put("appName", app.appName)
                put("shortDescription", app.shortDescription)
                put("iconUrl", app.iconUrl)
                put("platforms", JSONArray(app.platforms))
                put("storeLinks", JSONObject(app.storeLinks))
                put("iosAppStoreId", app.iosAppStoreId)
                put("priority", app.priority)
                put("enabled", app.enabled)
            }
            jsonArray.put(obj)
        }
        prefs.edit()
            .putString(KEY_APPS, jsonArray.toString())
            .putLong(KEY_CACHE_TIME, System.currentTimeMillis())
            .apply()
    }

    fun loadApps(): List<PromoApp> {
        val json = prefs.getString(KEY_APPS, null) ?: return emptyList()
        return try {
            val array = JSONArray(json)
            (0 until array.length()).map { i ->
                val obj = array.getJSONObject(i)
                val platforms = mutableListOf<String>()
                val platformsArray = obj.getJSONArray("platforms")
                for (j in 0 until platformsArray.length()) {
                    platforms.add(platformsArray.getString(j))
                }
                val storeLinks = mutableMapOf<String, String>()
                val linksObj = obj.getJSONObject("storeLinks")
                linksObj.keys().forEach { key ->
                    storeLinks[key] = linksObj.getString(key)
                }
                PromoApp(
                    appId = obj.getString("appId"),
                    appName = obj.optString("appName", ""),
                    shortDescription = obj.optString("shortDescription", ""),
                    iconUrl = obj.optString("iconUrl", ""),
                    platforms = platforms,
                    storeLinks = storeLinks,
                    iosAppStoreId = obj.optString("iosAppStoreId", ""),
                    priority = obj.optInt("priority", 10),
                    enabled = obj.optBoolean("enabled", true),
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun saveConfig(config: PromoConfig) {
        val obj = JSONObject().apply {
            put("enabled", config.enabled)
            put("selectionMode", config.selectionMode)
            put("minAppOpenCount", config.minAppOpenCount)
            put("popupTitle", config.popupTitle)
        }
        prefs.edit().putString(KEY_CONFIG, obj.toString()).apply()
    }

    fun loadConfig(): PromoConfig? {
        val json = prefs.getString(KEY_CONFIG, null) ?: return null
        return try {
            val obj = JSONObject(json)
            PromoConfig(
                enabled = obj.optBoolean("enabled", true),
                selectionMode = obj.optString("selectionMode", "weighted_random"),
                minAppOpenCount = obj.optInt("minAppOpenCount", 3),
                popupTitle = obj.optString("popupTitle", "개발자의 다른 앱"),
            )
        } catch (e: Exception) {
            null
        }
    }

    fun clearCache() {
        prefs.edit().clear().apply()
    }
}
