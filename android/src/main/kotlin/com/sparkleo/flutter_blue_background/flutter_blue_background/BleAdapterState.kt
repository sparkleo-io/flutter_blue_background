package com.sparkleo.flutter_blue_background.flutter_blue_background

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager

/**
 * Reads and maps the system Bluetooth adapter state to the cross-platform
 * string values consumed by Dart [BleAdapterState].
 */
object BleAdapterState {

    fun getState(context: Context): String {
        if (!context.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)) {
            return "unsupported"
        }

        if (!BlePermissions.hasConnectPermission(context)) {
            FbbLog.warning("getAdapterState: missing BLUETOOTH_CONNECT permission")
            return "unauthorized"
        }

        val adapter = bluetoothAdapter(context) ?: return "unsupported"

        return try {
            when (adapter.state) {
                BluetoothAdapter.STATE_ON -> "on"
                BluetoothAdapter.STATE_TURNING_ON -> "turningOn"
                BluetoothAdapter.STATE_OFF -> "off"
                BluetoothAdapter.STATE_TURNING_OFF -> "turningOff"
                else -> "unknown"
            }
        } catch (e: SecurityException) {
            FbbLog.warning("getAdapterState: SecurityException — ${e.message}")
            "unauthorized"
        }
    }

    fun isReady(context: Context): Boolean = getState(context) == "on"

    private fun bluetoothAdapter(context: Context): BluetoothAdapter? {
        return try {
            val manager =
                context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            manager?.adapter
        } catch (e: SecurityException) {
            FbbLog.warning("bluetoothAdapter: SecurityException — ${e.message}")
            null
        }
    }
}
