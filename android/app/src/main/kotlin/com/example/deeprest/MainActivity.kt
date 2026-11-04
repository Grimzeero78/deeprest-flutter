package com.example.deeprest

import android.Manifest
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private var notifResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "deeprest/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageAccess" -> result.success(hasUsageAccess())

                    "openUsageAccessSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(true)
                    }

                    "requestNotifications" -> {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                        ) {
                            notifResult = result
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 2001)
                        } else {
                            result.success(true)
                        }
                    }

                    "usageToday" -> result.success(usageToday())

                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == 2001) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            notifResult?.success(granted)
            notifResult = null
        } else {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    /** Usage access is granted via AppOps (Settings > Usage access). */
    private fun hasUsageAccess(): Boolean {
        val ops = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= 29) {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * Today's screen time as measured by the OS (UsageStatsManager) — the same
     * source Digital Wellbeing uses. Returns { granted, minutes, topApps }.
     */
    private fun usageToday(): Map<String, Any> {
        if (!hasUsageAccess()) {
            return mapOf("granted" to false, "minutes" to 0, "topApps" to emptyList<Map<String, Any>>())
        }
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val stats = usm.queryAndAggregateUsageStats(cal.timeInMillis, System.currentTimeMillis())

        var totalMs = 0L
        val apps = mutableListOf<Pair<String, Int>>()
        for (s in stats.values) {
            if (s.packageName == packageName) continue // never count DeepRest itself
            val ms = s.totalTimeInForeground
            if (ms < 60_000) continue // ignore sub-minute touches
            totalMs += ms
            val label = try {
                packageManager.getApplicationLabel(
                    packageManager.getApplicationInfo(s.packageName, 0)
                ).toString()
            } catch (e: Exception) {
                s.packageName
            }
            apps.add(Pair(label, (ms / 60_000).toInt()))
        }
        apps.sortByDescending { it.second }
        return mapOf(
            "granted" to true,
            "minutes" to (totalMs / 60_000).toInt(),
            "topApps" to apps.take(5).map { mapOf("name" to it.first, "minutes" to it.second) }
        )
    }
}
