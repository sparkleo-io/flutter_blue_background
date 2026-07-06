package com.sparkleo.flutter_blue_background.flutter_blue_background

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Restarts the background service after a device reboot or an app update, but
 * only if the app previously had the service running.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON" &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }

        val prefs = context.getSharedPreferences(
            FlutterBlueBackgroundService.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        val shouldStart = prefs.getBoolean(FlutterBlueBackgroundService.KEY_SERVICE_ENABLED, false)
        if (!shouldStart) return

        val serviceIntent = Intent(context, FlutterBlueBackgroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
