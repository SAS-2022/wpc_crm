package com.wisora.wpc

import android.app.ActivityManager
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * "wpc/device": what can stop background tracking on this phone (2026-10-19,
 * after a phone paused the app for hours with every normal setting fine).
 * - info: manufacturer, background restriction ("Restricted" battery usage)
 *   and the app standby bucket (45 = restricted, the deepest sleep).
 * - openBackgroundSettings: the maker's auto-start / sleeping-apps page when
 *   known, else the app's settings page.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wpc/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "info" -> result.success(info())
                "openBackgroundSettings" -> result.success(openBackgroundSettings())
                else -> result.notImplemented()
            }
        }
    }

    private fun info(): Map<String, Any?> {
        var restricted: Boolean? = null
        var bucket: Int? = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            restricted = am.isBackgroundRestricted
            val usage = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            bucket = usage.appStandbyBucket
        }
        return mapOf(
            "manufacturer" to Build.MANUFACTURER.lowercase(),
            "backgroundRestricted" to restricted,
            "standbyBucket" to bucket,
        )
    }

    /** Known auto-start / background pages per maker; true when one opened. */
    private fun openBackgroundSettings(): Boolean {
        val candidates = listOf(
            ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
            ComponentName("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity"),
            ComponentName("com.samsung.android.sm", "com.samsung.android.sm.battery.ui.BatteryActivity"),
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
            ComponentName("com.hihonor.systemmanager", "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
            ComponentName("com.oplus.safecenter", "com.oplus.safecenter.permission.startup.StartupAppListActivity"),
            ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
            ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"),
        )
        val maker = Build.MANUFACTURER.lowercase()
        val mine = candidates.filter { c ->
            when {
                maker.contains("xiaomi") || maker.contains("redmi") || maker.contains("poco") -> c.packageName.startsWith("com.miui")
                maker.contains("samsung") -> c.packageName.startsWith("com.samsung")
                maker.contains("huawei") -> c.packageName.startsWith("com.huawei")
                maker.contains("honor") -> c.packageName.startsWith("com.hihonor") || c.packageName.startsWith("com.huawei")
                maker.contains("oppo") || maker.contains("realme") -> c.packageName.startsWith("com.coloros") || c.packageName.startsWith("com.oplus")
                maker.contains("oneplus") -> c.packageName.startsWith("com.oneplus") || c.packageName.startsWith("com.oplus")
                maker.contains("vivo") -> c.packageName.startsWith("com.vivo")
                else -> false
            }
        }
        for (c in mine) {
            try {
                startActivity(Intent().setComponent(c).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (_: Exception) {
                // Not on this phone / version: try the next one.
            }
        }
        startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        return false
    }
}
