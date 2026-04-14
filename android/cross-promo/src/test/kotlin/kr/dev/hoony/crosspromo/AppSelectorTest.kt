package kr.dev.hoony.crosspromo

import kr.dev.hoony.crosspromo.internal.AppSelector
import kr.dev.hoony.crosspromo.model.PromoApp
import org.junit.Assert.*
import org.junit.Test

class AppSelectorTest {

    private fun makeApp(
        appId: String,
        platforms: List<String> = listOf("android", "ios"),
        enabled: Boolean = true,
        priority: Int = 10,
    ) = PromoApp(
        appId = appId,
        appName = appId,
        platforms = platforms,
        enabled = enabled,
        priority = priority,
    )

    @Test
    fun `filterApps excludes current app`() {
        val apps = listOf(makeApp("app1"), makeApp("app2"), makeApp("app3"))
        val filtered = AppSelector.filterApps(apps, currentAppId = "app2")
        assertEquals(2, filtered.size)
        assertTrue(filtered.none { it.appId == "app2" })
    }

    @Test
    fun `filterApps excludes apps not on current platform`() {
        val apps = listOf(
            makeApp("app1", platforms = listOf("android")),
            makeApp("app2", platforms = listOf("ios")),
            makeApp("app3", platforms = listOf("android", "ios")),
        )
        val filtered = AppSelector.filterApps(apps, currentAppId = "none", platform = "android")
        assertEquals(2, filtered.size)
        assertTrue(filtered.any { it.appId == "app1" })
        assertTrue(filtered.any { it.appId == "app3" })
    }

    @Test
    fun `filterApps excludes disabled apps`() {
        val apps = listOf(
            makeApp("app1", enabled = true),
            makeApp("app2", enabled = false),
        )
        val filtered = AppSelector.filterApps(apps, currentAppId = "none")
        assertEquals(1, filtered.size)
        assertEquals("app1", filtered.first().appId)
    }

    @Test
    fun `selectWeightedRandom returns null for empty list`() {
        assertNull(AppSelector.selectWeightedRandom(emptyList()))
    }

    @Test
    fun `selectWeightedRandom returns single app`() {
        val app = makeApp("app1")
        assertEquals(app, AppSelector.selectWeightedRandom(listOf(app)))
    }

    @Test
    fun `selectWeightedRandom returns an app from the list`() {
        val apps = listOf(makeApp("app1"), makeApp("app2"), makeApp("app3"))
        repeat(100) {
            val selected = AppSelector.selectWeightedRandom(apps)
            assertNotNull(selected)
            assertTrue(apps.contains(selected))
        }
    }

    @Test
    fun `selectWeightedRandom respects priority weights`() {
        val highPriority = makeApp("high", priority = 100)
        val lowPriority = makeApp("low", priority = 1)
        val apps = listOf(highPriority, lowPriority)

        var highCount = 0
        repeat(1000) {
            if (AppSelector.selectWeightedRandom(apps)?.appId == "high") highCount++
        }
        // High priority should be selected much more often (~99% of the time)
        assertTrue("highCount=$highCount should be > 900", highCount > 900)
    }
}
