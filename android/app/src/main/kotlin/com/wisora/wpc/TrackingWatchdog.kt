package com.wisora.wpc

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import id.flutter.flutter_background_service.BackgroundService
import java.util.concurrent.TimeUnit

/**
 * Tracking watchdog (2026-11-08, user: phone makers close the app and it
 * stops sharing). Android runs this job about every 15 minutes (the
 * shortest WorkManager allows; Doze can delay it) also after the app was
 * closed and after a reboot. When the tracking service should run but
 * doesn't, it starts it again; the Dart service then decides itself
 * whether to share (role, hours, this phone) and logs "restarted".
 * Force-stop cancels the job (Android's rule) until the app is opened.
 */
class TrackingWatchdogWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val ctx = applicationContext
        val config = ctx.getSharedPreferences("id.flutter.background_service", Context.MODE_PRIVATE)
        // Stopped on purpose (sign-out, not a tracked person) or never set up.
        if (config.getBoolean("is_manually_stopped", false)) return Result.success()
        if (config.getLong("background_handle", 0L) == 0L) return Result.success()
        if (serviceRunning(ctx)) return Result.success()
        // Read by tracking_service.dart (shared_preferences key "watchdogRestartAt").
        val prefs = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().putLong("flutter.watchdogRestartAt", System.currentTimeMillis()).commit()
        try {
            ContextCompat.startForegroundService(ctx, Intent(ctx, BackgroundService::class.java))
        } catch (e: Exception) {
            // Android 12+ refuses background starts unless battery
            // optimization is off for the app; the setup steps ask for that.
            prefs.edit().remove("flutter.watchdogRestartAt").apply()
        }
        return Result.success()
    }

    @Suppress("DEPRECATION")
    private fun serviceRunning(ctx: Context): Boolean {
        val manager = ctx.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return manager.getRunningServices(Int.MAX_VALUE).any {
            it.service.className == BackgroundService::class.java.name
        }
    }

    companion object {
        private const val NAME = "trackingWatchdog"

        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<TrackingWatchdogWorker>(15, TimeUnit.MINUTES).build()
            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(NAME)
        }
    }
}
