package com.yinghua.yinghua

import android.annotation.SuppressLint
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.core.content.pm.PackageInfoCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    private val channelName = "com.yinghua.yinghua/background"
    private val updateChannelName = "com.yinghua.yinghua/update"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(batteryStatus())
                    "requestIgnoreBattery" -> result.success(requestIgnoreBattery())
                    "openBatterySettings" -> {
                        openBatterySettings()
                        result.success(true)
                    }
                    "openAutoStart" -> result.success(openAutoStart())
                    "requestNotificationPermission" -> result.success(requestNotifications())
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstall" -> result.success(canInstallPackages())
                    "openInstallSettings" -> {
                        openInstallSettings()
                        result.success(true)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        result.success(if (path.isNullOrBlank()) false else installApk(path))
                    }
                    "apkVersion" -> {
                        val path = call.argument<String>("path")
                        result.success(if (path.isNullOrBlank()) null else apkVersion(path))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** 读取 APK 里真实的 versionName / versionCode，用于拦截缓存里的旧安装包。 */
    private fun apkVersion(path: String): Map<String, Any>? {
        return try {
            val info = packageManager.getPackageArchiveInfo(path, 0) ?: return null
            mapOf(
                "versionName" to (info.versionName ?: ""),
                "versionCode" to PackageInfoCompat.getLongVersionCode(info)
            )
        } catch (_: Exception) {
            null
        }
    }

    /** Android 8+ 需要用户允许「安装未知应用」。 */
    private fun canInstallPackages(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()

    private fun installApk(path: String): Boolean {
        return try {
            val file = File(path)
            if (!file.exists() || !canInstallPackages()) return false
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                file
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openInstallSettings() {
        try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName")
                )
            } else {
                Intent(Settings.ACTION_SETTINGS)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (_: Exception) {
            // 系统页面不可用时忽略。
        }
    }

    private fun batteryStatus(): Map<String, Any> {
        val ignoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.isIgnoringBatteryOptimizations(packageName)
        } else {
            true
        }
        val notifications = if (Build.VERSION.SDK_INT >= 33) {
            checkSelfPermission("android.permission.POST_NOTIFICATIONS") ==
                PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        return mapOf(
            "ignoringBattery" to ignoring,
            "notifications" to notifications,
            "manufacturer" to (Build.MANUFACTURER ?: ""),
            "sdk" to Build.VERSION.SDK_INT,
        )
    }

    @SuppressLint("BatteryLife")
    private fun requestIgnoreBattery(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (pm.isIgnoringBatteryOptimizations(packageName)) return true
        return try {
            val intent = Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
            true
        } catch (_: Exception) {
            openBatterySettings()
            false
        }
    }

    private fun openBatterySettings() {
        try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            } else {
                Intent(Settings.ACTION_SETTINGS)
            }
            startActivity(intent)
        } catch (_: Exception) {
            // 个别系统没有这个页面，忽略。
        }
    }

    private fun requestNotifications(): Boolean {
        if (Build.VERSION.SDK_INT < 33) return true
        if (checkSelfPermission("android.permission.POST_NOTIFICATIONS") ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return true
        }
        requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 1001)
        return false
    }

    /** 国产 ROM 的自启动管理页，逐个尝试，失败返回 false。 */
    private fun openAutoStart(): Boolean {
        val candidates = listOf(
            ComponentName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity"
            ),
            ComponentName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
            ),
            ComponentName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.optimize.process.ProtectActivity"
            ),
            ComponentName(
                "com.oppo.safe",
                "com.oppo.safe.permission.startup.StartupAppListActivity"
            ),
            ComponentName(
                "com.vivo.permissionmanager",
                "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
            ),
            ComponentName(
                "com.oneplus.security",
                "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"
            ),
            ComponentName(
                "com.samsung.android.lool",
                "com.samsung.android.sm.ui.battery.BatteryActivity"
            ),
        )
        for (component in candidates) {
            try {
                val intent = Intent().apply {
                    this.component = component
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // 尝试下一个厂商。
            }
        }
        return false
    }
}
