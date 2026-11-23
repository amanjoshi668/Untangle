package com.amanjoshi.untangle_app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

object ReminderScheduler {
    const val CHANNEL_ID = "untangle_reflection_reminders"
    const val ACTION_AM = "com.amanjoshi.untangle_app.REMINDER_AM"
    const val ACTION_PM = "com.amanjoshi.untangle_app.REMINDER_PM"
    private const val PREFS = "untangle_native_reminders"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(
                CHANNEL_ID,
                "Decision & Spaced Recall Reminders",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Gentle focus and SuperMemo decision review check-ins"
            }
            nm.createNotificationChannel(ch)
        }
    }

    fun saveAndApply(context: Context, enabled: Boolean, amH: Int, amM: Int, pmH: Int, pmM: Int) {
        ensureChannel(context)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean("enabled", enabled)
            .putInt("amH", amH)
            .putInt("amM", amM)
            .putInt("pmH", pmH)
            .putInt("pmM", pmM)
            .apply()

        if (enabled) {
            scheduleSingle(context, ACTION_AM, 101, amH, amM, false)
            scheduleSingle(context, ACTION_PM, 102, pmH, pmM, false)
        } else {
            cancelSingle(context, ACTION_AM, 101)
            cancelSingle(context, ACTION_PM, 102)
        }
    }

    fun rescheduleSavedIfEnabled(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("enabled", false)) return
        ensureChannel(context)
        scheduleSingle(context, ACTION_AM, 101, prefs.getInt("amH", 8), prefs.getInt("amM", 30), false)
        scheduleSingle(context, ACTION_PM, 102, prefs.getInt("pmH", 20), prefs.getInt("pmM", 30), false)
    }

    fun scheduleNextForAction(context: Context, action: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("enabled", false)) return
        if (action == ACTION_AM) {
            scheduleSingle(context, ACTION_AM, 101, prefs.getInt("amH", 8), prefs.getInt("amM", 30), true)
        } else if (action == ACTION_PM) {
            scheduleSingle(context, ACTION_PM, 102, prefs.getInt("pmH", 20), prefs.getInt("pmM", 30), true)
        }
    }

    private fun scheduleSingle(context: Context, action: String, reqCode: Int, hour: Int, minute: Int, forceTomorrow: Boolean) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java).apply { this.action = action }
        val pi = PendingIntent.getBroadcast(
            context,
            reqCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (forceTomorrow || cal.timeInMillis <= System.currentTimeMillis() + 5000L) {
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pi)
    }

    private fun cancelSingle(context: Context, action: String, reqCode: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java).apply { this.action = action }
        val pi = PendingIntent.getBroadcast(
            context,
            reqCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        am.cancel(pi)
    }
}
