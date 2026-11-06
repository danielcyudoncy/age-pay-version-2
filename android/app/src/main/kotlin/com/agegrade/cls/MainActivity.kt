package com.agegrade.cls

import android.content.Context
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun getRenderMode(): RenderMode = RenderMode.texture

    private val PROXIMITY_CHANNEL = "com.agegrade.cls/proximity"
    private var proximityWakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROXIMITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    enableProximitySensor()
                    result.success(true)
                }
                "disable" -> {
                    disableProximitySensor()
                    result.success(true)
                }
                "isSupported" -> {
                    result.success(isProximitySupported())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isProximitySupported(): Boolean {
        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            powerManager.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)
        } else {
            false
        }
    }

    private fun enableProximitySensor() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
            if (isProximitySupported()) {
                if (proximityWakeLock == null) {
                    proximityWakeLock = powerManager.newWakeLock(
                        PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK,
                        "agepay:proximity_wakelock"
                    ).apply {
                        setReferenceCounted(false)
                    }
                }
                if (proximityWakeLock?.isHeld == false) {
                    proximityWakeLock?.acquire()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun disableProximitySensor() {
        try {
            if (proximityWakeLock?.isHeld == true) {
                proximityWakeLock?.release()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        disableProximitySensor()
        proximityWakeLock = null
        super.onDestroy()
    }
}
