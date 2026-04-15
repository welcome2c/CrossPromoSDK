package kr.dev.hoony.crosspromo

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kr.dev.hoony.crosspromo.data.CacheManager
import kr.dev.hoony.crosspromo.data.FirestoreService
import kr.dev.hoony.crosspromo.data.FrequencyManager
import kr.dev.hoony.crosspromo.internal.AppSelector
import kr.dev.hoony.crosspromo.model.PromoApp
import kr.dev.hoony.crosspromo.model.PromoConfig
import kr.dev.hoony.crosspromo.ui.CrossPromoDialog

object CrossPromo {

    private var currentAppId: String = ""
    private var isInitialized = false

    private lateinit var cacheManager: CacheManager
    private lateinit var frequencyManager: FrequencyManager
    private lateinit var firestoreService: FirestoreService

    private var apps: List<PromoApp> = emptyList()
    private var config: PromoConfig = PromoConfig()
    private var isDataLoaded = false

    /**
     * Initialize the SDK. Call this in Application.onCreate() or MainActivity.onCreate().
     *
     * @param context Application context
     * @param currentAppId The package name of the host app (e.g., "kr.dev.hoony.voda")
     * @param firebaseProjectId The Firebase project ID for CrossPromo Firestore (default: "crosspromosdk")
     */
    private var debugMode = false

    fun initialize(
        context: Context,
        currentAppId: String,
        firebaseProjectId: String = "crosspromosdk",
        debug: Boolean = false,
    ) {
        this.currentAppId = currentAppId
        this.debugMode = debug
        this.cacheManager = CacheManager(context.applicationContext)
        this.frequencyManager = FrequencyManager(context.applicationContext)
        this.firestoreService = FirestoreService(firebaseProjectId)
        this.isInitialized = true

        frequencyManager.incrementAppOpenCount()
        frequencyManager.resetSession()

        CoroutineScope(Dispatchers.IO).launch {
            loadData()
        }
    }

    private suspend fun loadData() {
        // Try cache first
        if (cacheManager.isCacheValid()) {
            apps = cacheManager.loadApps()
            config = cacheManager.loadConfig() ?: PromoConfig()
            if (apps.isNotEmpty()) {
                apps = AppSelector.filterApps(apps, currentAppId)
                isDataLoaded = true
                return
            }
        }

        // Fetch from Firestore
        try {
            val allApps = firestoreService.fetchApps()
            config = firestoreService.fetchConfig()

            // Cache raw data before filtering
            cacheManager.saveApps(allApps)
            cacheManager.saveConfig(config)

            // Filter for current platform and app
            apps = AppSelector.filterApps(allApps, currentAppId)
            isDataLoaded = true
        } catch (e: Exception) {
            // Use stale cache as fallback
            apps = AppSelector.filterApps(cacheManager.loadApps(), currentAppId)
            config = cacheManager.loadConfig() ?: PromoConfig()
            isDataLoaded = apps.isNotEmpty()
        }
    }

    /**
     * Check if a promo can be shown right now.
     */
    fun canShow(): Boolean {
        if (!isInitialized || !isDataLoaded) return false
        if (debugMode) return apps.isNotEmpty()
        if (!config.enabled) return false
        if (apps.isEmpty()) return false
        return frequencyManager.canShow(config.minAppOpenCount)
    }

    /**
     * Select an app to promote. Returns null if no app is available.
     */
    fun selectApp(): PromoApp? {
        if (!canShow()) return null
        return AppSelector.selectWeightedRandom(apps)
    }

    /**
     * Record that the promo was dismissed for today.
     */
    fun dismissForToday() {
        frequencyManager.dismissForToday()
    }

    /**
     * Record that the promo was shown in this session.
     */
    fun markShown() {
        frequencyManager.markSessionShown()
    }

    /**
     * Get the popup title from config.
     */
    fun getPopupTitle(): String = config.popupTitle

    /**
     * Open the Play Store page for the given app.
     */
    fun openPlayStore(context: Context, appId: String) {
        try {
            context.startActivity(
                Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$appId")).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
        } catch (e: ActivityNotFoundException) {
            context.startActivity(
                Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("https://play.google.com/store/apps/details?id=$appId")
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
        }
    }

    /**
     * Composable helper: shows the cross-promo dialog if conditions are met.
     * Place this in your screen composable.
     *
     * Usage:
     * ```
     * CrossPromo.ShowIfNeeded()
     * ```
     */
    @Composable
    fun ShowIfNeeded(
        delayMillis: Long = 2000L,
    ) {
        if (!isInitialized) return

        var showDialog by remember { mutableStateOf(false) }
        var selectedApp by remember { mutableStateOf<PromoApp?>(null) }

        LaunchedEffect(Unit) {
            kotlinx.coroutines.delay(delayMillis)
            if (canShow()) {
                selectedApp = selectApp()
                if (selectedApp != null) {
                    showDialog = true
                }
            }
        }

        if (showDialog && selectedApp != null) {
            val context = androidx.compose.ui.platform.LocalContext.current
            CrossPromoDialog(
                app = selectedApp!!,
                title = getPopupTitle(),
                onInstall = {
                    openPlayStore(context, selectedApp!!.appId)
                    markShown()
                    showDialog = false
                },
                onDismissToday = {
                    dismissForToday()
                    showDialog = false
                },
                onClose = {
                    markShown()
                    showDialog = false
                },
            )
        }
    }
}
