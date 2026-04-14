package kr.dev.hoony.crosspromo.internal

import kr.dev.hoony.crosspromo.model.PromoApp
import kotlin.random.Random

internal object AppSelector {

    /**
     * Filter apps for the current platform, excluding the current app and disabled apps.
     */
    fun filterApps(
        apps: List<PromoApp>,
        currentAppId: String,
        platform: String = "android",
    ): List<PromoApp> {
        return apps.filter { app ->
            app.enabled &&
                app.appId != currentAppId &&
                app.platforms.contains(platform)
        }
    }

    /**
     * Select an app using weighted random selection based on priority.
     * Returns null if the list is empty.
     */
    fun selectWeightedRandom(apps: List<PromoApp>): PromoApp? {
        if (apps.isEmpty()) return null
        if (apps.size == 1) return apps.first()

        val totalWeight = apps.sumOf { it.priority.coerceAtLeast(1) }
        var random = Random.nextInt(totalWeight)

        for (app in apps) {
            random -= app.priority.coerceAtLeast(1)
            if (random < 0) return app
        }

        return apps.last()
    }
}
