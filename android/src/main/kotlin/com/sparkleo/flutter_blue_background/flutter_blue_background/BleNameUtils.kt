package com.sparkleo.flutter_blue_background.flutter_blue_background

/**
 * Normalizes BLE device names the same way [flutter_blue_plus] treats
 * [advName] / [platformName]: advertisement local names are distinct from
 * platform/cached names, and placeholder strings are not real names.
 */
object BleNameUtils {

    /** Name from the advertisement packet (ScanRecord device name / iOS local name). */
    fun normalizeAdvertisedName(raw: String?): String? {
        val trimmed = raw?.trim() ?: return null
        if (trimmed.isEmpty() || isPlaceholder(trimmed)) return null
        return trimmed
    }

    /** Platform/cached name (Android [BluetoothDevice.getName], iOS peripheral.name). */
    fun normalizePlatformName(raw: String?): String? {
        val trimmed = raw?.trim() ?: return null
        if (trimmed.isEmpty() || isPlaceholder(trimmed)) return null
        return trimmed
    }

    fun hasAdvertisedName(raw: String?): Boolean = normalizeAdvertisedName(raw) != null

    private fun isPlaceholder(name: String): Boolean {
        return when (name.lowercase()) {
            "unknown", "(unknown)", "n/a", "null", "<unknown>" -> true
            else -> false
        }
    }
}
