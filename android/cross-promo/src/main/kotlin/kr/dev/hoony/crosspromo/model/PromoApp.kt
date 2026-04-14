package kr.dev.hoony.crosspromo.model

data class PromoApp(
    val appId: String = "",
    val appName: String = "",
    val shortDescription: String = "",
    val iconUrl: String = "",
    val platforms: List<String> = emptyList(),
    val storeLinks: Map<String, String> = emptyMap(),
    val iosAppStoreId: String = "",
    val priority: Int = 10,
    val enabled: Boolean = true,
)
