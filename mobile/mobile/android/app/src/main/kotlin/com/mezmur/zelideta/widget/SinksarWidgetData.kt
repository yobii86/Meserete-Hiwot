package com.mezmur.zelideta.widget

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Data model for the Sinksar Home-Screen Widget.
 * Handles SharedPreferences persistence and robust fallback generation.
 */
data class SinksarWidgetData(
    val gregorianDate: String,
    val ethiopianDate: String,
    val formattedDate: String,
    val formattedFull: String,
    val featuredTitle: String,
    val annualFeasts: List<String>,
    val monthlyFeasts: List<String>,
    val summary: String,
    val isFasting: Boolean,
    val fastingReason: String?,
    val lastUpdatedMillis: Long,
    val isOffline: Boolean
) {
    val annualFeastsFormatted: String
        get() = if (annualFeasts.isNotEmpty()) {
            "📌 ዓመታዊ፦ " + annualFeasts.take(2).joinToString("፣ ")
        } else {
            ""
        }

    val monthlyFeastsFormatted: String
        get() = if (monthlyFeasts.isNotEmpty()) {
            "📌 ወርኀዊ፦ " + monthlyFeasts.take(2).joinToString("፣ ")
        } else {
            ""
        }

    val displaySummary: String
        get() = when {
            summary.isNotBlank() -> summary
            annualFeasts.isNotEmpty() && monthlyFeasts.isNotEmpty() ->
                "${annualFeasts.joinToString("፣ ")} · ${monthlyFeasts.joinToString("፣ ")}"
            annualFeasts.isNotEmpty() -> annualFeasts.joinToString("፣ ")
            monthlyFeasts.isNotEmpty() -> monthlyFeasts.joinToString("፣ ")
            else -> "የዕለቱ የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ስንክሳር እና መታሰቢያ"
        }

    val lastUpdatedDisplay: String
        get() {
            if (lastUpdatedMillis <= 0) return ""
            val sdf = SimpleDateFormat("HH:mm", Locale.getDefault())
            sdf.timeZone = TimeZone.getTimeZone("Africa/Addis_Ababa")
            val timeStr = sdf.format(Date(lastUpdatedMillis))
            val prefix = if (isOffline) "ከመስመር ውጭ · " else "የተሻሻለው፦ "
            return "$prefix$timeStr"
        }

    fun saveToPrefs(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().apply {
            putString(KEY_GREG_DATE, gregorianDate)
            putString(KEY_ETH_DATE, ethiopianDate)
            putString(KEY_FORMATTED_DATE, formattedDate)
            putString(KEY_FORMATTED_FULL, formattedFull)
            putString(KEY_FEATURED_TITLE, featuredTitle)
            putString(KEY_ANNUAL_FEASTS, JSONArray(annualFeasts).toString())
            putString(KEY_MONTHLY_FEASTS, JSONArray(monthlyFeasts).toString())
            putString(KEY_SUMMARY, summary)
            putBoolean(KEY_IS_FASTING, isFasting)
            putString(KEY_FASTING_REASON, fastingReason ?: "")
            putLong(KEY_LAST_UPDATED, lastUpdatedMillis)
            putBoolean(KEY_IS_OFFLINE, isOffline)
            apply()
        }
    }

    companion object {
        const val PREFS_NAME = "sinksar_widget_prefs"
        private const val KEY_GREG_DATE = "gregorian_date"
        private const val KEY_ETH_DATE = "ethiopian_date"
        private const val KEY_FORMATTED_DATE = "formatted_date"
        private const val KEY_FORMATTED_FULL = "formatted_full"
        private const val KEY_FEATURED_TITLE = "featured_title"
        private const val KEY_ANNUAL_FEASTS = "annual_feasts"
        private const val KEY_MONTHLY_FEASTS = "monthly_feasts"
        private const val KEY_SUMMARY = "summary"
        private const val KEY_IS_FASTING = "is_fasting"
        private const val KEY_FASTING_REASON = "fasting_reason"
        private const val KEY_LAST_UPDATED = "last_updated"
        private const val KEY_IS_OFFLINE = "is_offline"

        fun fromLocalCalendar(): SinksarWidgetData {
            val eth = EthiopianCalendarHelper.todayInAddis()
            val monthly = listOf(eth.monthlyCommemoration)
            val fastingReason = if (eth.isFastingDay) "የረቡዕና ዓርብ ጾም" else null

            return SinksarWidgetData(
                gregorianDate = eth.gregorianDateIso,
                ethiopianDate = String.format(Locale.US, "%04d-%02d-%02d", eth.year, eth.month, eth.day),
                formattedDate = eth.formattedDate,
                formattedFull = eth.formattedFull,
                featuredTitle = eth.monthlyCommemoration,
                annualFeasts = emptyList(),
                monthlyFeasts = monthly,
                summary = "ወርኀዊ መታሰቢያ፦ ${eth.monthlyCommemoration}",
                isFasting = eth.isFastingDay,
                fastingReason = fastingReason,
                lastUpdatedMillis = System.currentTimeMillis(),
                isOffline = true
            )
        }

        fun loadFromPrefs(context: Context): SinksarWidgetData {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val gregDate = prefs.getString(KEY_GREG_DATE, null)
            val today = EthiopianCalendarHelper.todayInAddis()

            // If preferences are empty or belong to an older date, generate fresh local calendar data
            if (gregDate == null || gregDate != today.gregorianDateIso) {
                val fresh = fromLocalCalendar()
                fresh.saveToPrefs(context)
                return fresh
            }

            val annualList = mutableListOf<String>()
            val monthlyList = mutableListOf<String>()
            try {
                val aArr = JSONArray(prefs.getString(KEY_ANNUAL_FEASTS, "[]"))
                for (i in 0 until aArr.length()) annualList.add(aArr.getString(i))
                val mArr = JSONArray(prefs.getString(KEY_MONTHLY_FEASTS, "[]"))
                for (i in 0 until mArr.length()) monthlyList.add(mArr.getString(i))
            } catch (e: Exception) {}

            return SinksarWidgetData(
                gregorianDate = gregDate,
                ethiopianDate = prefs.getString(KEY_ETH_DATE, today.formattedDate) ?: today.formattedDate,
                formattedDate = prefs.getString(KEY_FORMATTED_DATE, today.formattedDate) ?: today.formattedDate,
                formattedFull = prefs.getString(KEY_FORMATTED_FULL, today.formattedFull) ?: today.formattedFull,
                featuredTitle = prefs.getString(KEY_FEATURED_TITLE, today.monthlyCommemoration) ?: today.monthlyCommemoration,
                annualFeasts = annualList,
                monthlyFeasts = if (monthlyList.isNotEmpty()) monthlyList else listOf(today.monthlyCommemoration),
                summary = prefs.getString(KEY_SUMMARY, "") ?: "",
                isFasting = prefs.getBoolean(KEY_IS_FASTING, today.isFastingDay),
                fastingReason = prefs.getString(KEY_FASTING_REASON, null)?.ifEmpty { null },
                lastUpdatedMillis = prefs.getLong(KEY_LAST_UPDATED, System.currentTimeMillis()),
                isOffline = prefs.getBoolean(KEY_IS_OFFLINE, false)
            )
        }

        fun fromJson(json: JSONObject, isOffline: Boolean = false): SinksarWidgetData {
            val dataObj = json.optJSONObject("data") ?: json
            val annualList = mutableListOf<String>()
            val monthlyList = mutableListOf<String>()

            val annualArr = dataObj.optJSONArray("annual_feasts")
            if (annualArr != null) {
                for (i in 0 until annualArr.length()) {
                    val item = annualArr.optJSONObject(i)
                    val title = item?.optString("title") ?: annualArr.optString(i)
                    if (title.isNotBlank()) annualList.add(title)
                }
            }

            val monthlyArr = dataObj.optJSONArray("monthly_feasts")
            if (monthlyArr != null) {
                for (i in 0 until monthlyArr.length()) {
                    val item = monthlyArr.optJSONObject(i)
                    val title = item?.optString("title") ?: monthlyArr.optString(i)
                    if (title.isNotBlank()) monthlyList.add(title)
                }
            }

            val gregDate = dataObj.optString("gregorian_date", "")
            val ethDate = dataObj.optString("ethiopian_date", "")
            val formattedDate = dataObj.optString("formatted_date", "")
            val formattedFull = dataObj.optString("formatted_full", "")
            val featuredTitle = dataObj.optString("featured_title", "")
            val summary = dataObj.optString("summary", "")
            val isFasting = dataObj.optBoolean("is_fasting", false)
            val fastingReason = dataObj.optString("fasting_reason").ifEmpty { null }

            return SinksarWidgetData(
                gregorianDate = gregDate,
                ethiopianDate = ethDate,
                formattedDate = formattedDate,
                formattedFull = formattedFull,
                featuredTitle = featuredTitle,
                annualFeasts = annualList,
                monthlyFeasts = monthlyList,
                summary = summary,
                isFasting = isFasting,
                fastingReason = fastingReason,
                lastUpdatedMillis = System.currentTimeMillis(),
                isOffline = isOffline
            )
        }

        fun fromMap(map: Map<String, Any?>, isOffline: Boolean = false): SinksarWidgetData {
            val gregDate = map["gregorian_date"]?.toString() ?: ""
            val ethDate = map["ethiopian_date"]?.toString() ?: ""
            val formattedDate = map["formatted_date"]?.toString() ?: ""
            val formattedFull = map["formatted_full"]?.toString() ?: ""
            val featuredTitle = map["featured_title"]?.toString() ?: ""
            val summary = map["summary"]?.toString() ?: ""
            val isFasting = map["is_fasting"] == true
            val fastingReason = map["fasting_reason"]?.toString()

            val annualList = mutableListOf<String>()
            val rawAnnual = map["annual_feasts"]
            if (rawAnnual is List<*>) {
                for (item in rawAnnual) {
                    if (item is Map<*, *>) {
                        val t = item["title"]?.toString()
                        if (!t.isNullOrBlank()) annualList.add(t)
                    } else if (item is String && item.isNotBlank()) {
                        annualList.add(item)
                    }
                }
            }

            val monthlyList = mutableListOf<String>()
            val rawMonthly = map["monthly_feasts"]
            if (rawMonthly is List<*>) {
                for (item in rawMonthly) {
                    if (item is Map<*, *>) {
                        val t = item["title"]?.toString()
                        if (!t.isNullOrBlank()) monthlyList.add(t)
                    } else if (item is String && item.isNotBlank()) {
                        monthlyList.add(item)
                    }
                }
            }

            return SinksarWidgetData(
                gregorianDate = gregDate,
                ethiopianDate = ethDate,
                formattedDate = formattedDate,
                formattedFull = formattedFull,
                featuredTitle = featuredTitle,
                annualFeasts = annualList,
                monthlyFeasts = monthlyList,
                summary = summary,
                isFasting = isFasting,
                fastingReason = fastingReason,
                lastUpdatedMillis = System.currentTimeMillis(),
                isOffline = isOffline
            )
        }
    }
}
