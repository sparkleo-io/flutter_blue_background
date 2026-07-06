package com.sparkleo.flutter_blue_background.flutter_blue_background

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * Centralized runtime Bluetooth permission checks for Android.
 */
object BlePermissions {

    /** Required to read adapter state and establish GATT connections (API 31+). */
    fun hasConnectPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return isGranted(context, Manifest.permission.BLUETOOTH_CONNECT)
    }

    /** Required to scan for BLE devices (API 31+). */
    fun hasScanPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return isGranted(context, Manifest.permission.ACCESS_FINE_LOCATION) ||
                isGranted(context, Manifest.permission.ACCESS_COARSE_LOCATION)
        }
        return isGranted(context, Manifest.permission.BLUETOOTH_SCAN)
    }

    /** All BLE permissions needed before scan + connect can work. */
    fun hasRequiredBlePermissions(context: Context): Boolean =
        hasConnectPermission(context) && hasScanPermission(context)

    private fun isGranted(context: Context, permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) ==
            PackageManager.PERMISSION_GRANTED
}
