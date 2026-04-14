package kr.dev.hoony.crosspromo.data

import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await
import kr.dev.hoony.crosspromo.model.PromoApp
import kr.dev.hoony.crosspromo.model.PromoConfig

internal class FirestoreService {

    private val db = FirebaseFirestore.getInstance()

    suspend fun fetchApps(): List<PromoApp> {
        val snapshot = db.collection("cross_promo_apps").get().await()
        return snapshot.documents.mapNotNull { doc ->
            try {
                PromoApp(
                    appId = doc.getString("appId") ?: return@mapNotNull null,
                    appName = doc.getString("appName") ?: "",
                    shortDescription = doc.getString("shortDescription") ?: "",
                    iconUrl = doc.getString("iconUrl") ?: "",
                    platforms = (doc.get("platforms") as? List<*>)
                        ?.filterIsInstance<String>() ?: emptyList(),
                    storeLinks = (doc.get("storeLinks") as? Map<*, *>)
                        ?.entries
                        ?.associate { (k, v) -> k.toString() to v.toString() }
                        ?: emptyMap(),
                    iosAppStoreId = doc.getString("iosAppStoreId") ?: "",
                    priority = doc.getLong("priority")?.toInt() ?: 10,
                    enabled = doc.getBoolean("enabled") ?: true,
                )
            } catch (e: Exception) {
                null
            }
        }
    }

    suspend fun fetchConfig(): PromoConfig {
        return try {
            val doc = db.collection("cross_promo_config").document("settings").get().await()
            if (doc.exists()) {
                PromoConfig(
                    enabled = doc.getBoolean("enabled") ?: true,
                    selectionMode = doc.getString("selectionMode") ?: "weighted_random",
                    minAppOpenCount = doc.getLong("minAppOpenCount")?.toInt() ?: 3,
                    popupTitle = doc.getString("popupTitle") ?: "개발자의 다른 앱",
                )
            } else {
                PromoConfig()
            }
        } catch (e: Exception) {
            PromoConfig()
        }
    }
}
