package kr.dev.hoony.crosspromo.data

import android.content.Context
import android.content.SharedPreferences
import java.time.LocalDate

internal class FrequencyManager(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("cross_promo_frequency", Context.MODE_PRIVATE)

    companion object {
        private const val KEY_DISMISS_DATE = "dismiss_date"
        private const val KEY_SESSION_SHOWN = "session_shown"
        private const val KEY_APP_OPEN_COUNT = "app_open_count"
    }

    fun incrementAppOpenCount() {
        val current = getAppOpenCount()
        prefs.edit().putInt(KEY_APP_OPEN_COUNT, current + 1).apply()
    }

    fun getAppOpenCount(): Int = prefs.getInt(KEY_APP_OPEN_COUNT, 0)

    fun isDismissedToday(): Boolean {
        val dismissDate = prefs.getString(KEY_DISMISS_DATE, null) ?: return false
        return dismissDate == LocalDate.now().toString()
    }

    fun dismissForToday() {
        prefs.edit().putString(KEY_DISMISS_DATE, LocalDate.now().toString()).apply()
    }

    fun isSessionShown(): Boolean = prefs.getBoolean(KEY_SESSION_SHOWN, false)

    fun markSessionShown() {
        prefs.edit().putBoolean(KEY_SESSION_SHOWN, true).apply()
    }

    fun resetSession() {
        prefs.edit().putBoolean(KEY_SESSION_SHOWN, false).apply()
    }

    fun canShow(minAppOpenCount: Int): Boolean {
        if (getAppOpenCount() < minAppOpenCount) return false
        if (isDismissedToday()) return false
        if (isSessionShown()) return false
        return true
    }
}
