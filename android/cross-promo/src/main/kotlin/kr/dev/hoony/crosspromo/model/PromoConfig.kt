package kr.dev.hoony.crosspromo.model

data class PromoConfig(
    val enabled: Boolean = true,
    val selectionMode: String = "weighted_random",
    val minAppOpenCount: Int = 3,
    val popupTitle: String = "개발자의 다른 앱",
)
