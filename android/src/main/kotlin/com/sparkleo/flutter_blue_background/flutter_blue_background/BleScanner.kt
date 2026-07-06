package com.sparkleo.flutter_blue_background.flutter_blue_background

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import android.os.ParcelUuid

/**
 * Owns the [BluetoothLeScanner] and translates a Dart `ScanConfig` map into
 * native [ScanFilter] / [ScanSettings], emitting discovered devices through
 * [ScanResultDispatcher].
 *
 * This is owned by [FlutterBlueBackgroundService] (not the Flutter plugin) so a
 * running scan survives the Flutter engine being torn down — e.g. when the app
 * is swiped away from recents while the foreground service keeps the process
 * alive.
 *
 * Cross-platform filters that Android cannot do natively in a portable way
 * ([nameFilter] substring match and [rssiThreshold]) are applied client-side so
 * behaviour matches iOS.
 */
class BleScanner(private val context: Context) {

    private var scanner: BluetoothLeScanner? = null
    private var activeCallback: ScanCallback? = null

    val isScanning: Boolean
        get() = ScanResultDispatcher.isScanning

    // Client-side filters captured from the active config.
    private var nameFilter: String? = null
    private var skipUnnamedDevices: Boolean = false
    private var rssiThreshold: Int? = null

    @SuppressLint("MissingPermission")
    fun startScan(config: Map<String, Any?>): Boolean {
        if (!BlePermissions.hasScanPermission(context)) {
            FbbLog.warning("Missing BLUETOOTH_SCAN / location permission")
            return false
        }

        val adapter = bluetoothAdapter()
        if (adapter == null || !adapter.isEnabled) {
            FbbLog.warning("Bluetooth adapter unavailable or disabled")
            return false
        }

        val leScanner = adapter.bluetoothLeScanner
        if (leScanner == null) {
            FbbLog.warning("BluetoothLeScanner unavailable")
            return false
        }

        // Restart cleanly if already scanning.
        if (isScanning) {
            stopScan()
        }

        nameFilter = (config["nameFilter"] as? String)?.takeIf { it.isNotEmpty() }
        skipUnnamedDevices = config["skipUnnamedDevices"] as? Boolean ?: false
        rssiThreshold = (config["rssiThreshold"] as? Number)?.toInt()

        // Fresh scan: drop results cached from a previous one.
        ScanResultDispatcher.clearCache()

        val filters = buildFilters(config)
        val settings = buildSettings(config)

        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                FbbLog.verbose("onScanResult: ${result.device.address} rssi=${result.rssi}")
                handleResult(result)
            }

            override fun onBatchScanResults(results: MutableList<ScanResult>) {
                results.forEach { handleResult(it) }
            }

            override fun onScanFailed(errorCode: Int) {
                FbbLog.error("Scan failed: $errorCode")
                ScanResultDispatcher.isScanning = false
                ScanResultDispatcher.error(
                    "scan_failed",
                    "BLE scan failed with error code $errorCode",
                )
            }
        }

        return try {
            leScanner.startScan(filters, settings, callback)
            scanner = leScanner
            activeCallback = callback
            ScanResultDispatcher.isScanning = true
            FbbLog.debug("Scan started (filters=${filters.size})")
            true
        } catch (e: Exception) {
            FbbLog.error("startScan threw: ${e.message}")
            false
        }
    }

    @SuppressLint("MissingPermission")
    fun stopScan(): Boolean {
        FbbLog.debug("stopScan")
        val leScanner = scanner
        val callback = activeCallback
        ScanResultDispatcher.isScanning = false
        nameFilter = null
        skipUnnamedDevices = false
        rssiThreshold = null
        if (leScanner == null || callback == null) return true
        return try {
            if (BlePermissions.hasScanPermission(context)) {
                leScanner.stopScan(callback)
            }
            true
        } catch (e: Exception) {
            FbbLog.error("stopScan threw: ${e.message}")
            false
        } finally {
            scanner = null
            activeCallback = null
        }
    }

    @SuppressLint("MissingPermission")
    private fun handleResult(result: ScanResult) {
        val record = result.scanRecord

        // Advertisement local name only — matches flutter_blue_plus advName.
        val advName = BleNameUtils.normalizeAdvertisedName(record?.deviceName)
        // Platform/cached name — matches flutter_blue_plus platformName.
        val platformName = BleNameUtils.normalizePlatformName(
            runCatching { result.device.name }.getOrNull(),
        )

        // skipUnnamedDevices filters on advertisement name only, not bonded/cached
        // names that Android/iOS may return as "Unknown".
        if (skipUnnamedDevices && advName == null) {
            return
        }

        val nameForFilter = advName ?: platformName
        nameFilter?.let { filter ->
            if (nameForFilter == null || !nameForFilter.contains(filter, ignoreCase = true)) {
                return
            }
        }

        // Client-side RSSI threshold.
        rssiThreshold?.let { threshold ->
            if (result.rssi < threshold) return
        }

        val serviceUuids = record?.serviceUuids?.map { it.uuid.toString() } ?: emptyList()

        val serviceData = HashMap<String, ByteArray>()
        record?.serviceData?.forEach { (uuid, bytes) ->
            serviceData[uuid.uuid.toString()] = bytes
        }

        val connectable: Boolean? =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) result.isConnectable else null

        val payload: Map<String, Any?> = mapOf(
            "deviceId" to result.device.address,
            "advName" to (advName ?: ""),
            "platformName" to (platformName ?: ""),
            "name" to (advName ?: platformName),
            "rssi" to result.rssi,
            "txPowerLevel" to record?.txPowerLevel,
            "connectable" to connectable,
            "manufacturerData" to firstManufacturerData(result),
            "serviceUuids" to serviceUuids,
            "serviceData" to serviceData,
            "timestampMillis" to System.currentTimeMillis(),
        )

        ScanResultDispatcher.emit(payload)
    }

    /**
     * Re-encodes the manufacturer-specific data with the 2-byte company id
     * prefix (little endian) so it matches the raw advertisement bytes that iOS
     * reports.
     */
    private fun firstManufacturerData(result: ScanResult): ByteArray? {
        val msd = result.scanRecord?.manufacturerSpecificData ?: return null
        if (msd.size() == 0) return null
        val companyId = msd.keyAt(0)
        val data = msd.valueAt(0) ?: return null
        val out = ByteArray(data.size + 2)
        out[0] = (companyId and 0xFF).toByte()
        out[1] = ((companyId shr 8) and 0xFF).toByte()
        System.arraycopy(data, 0, out, 2, data.size)
        return out
    }

    @Suppress("UNCHECKED_CAST")
    private fun buildFilters(config: Map<String, Any?>): List<ScanFilter> {
        val serviceUuids = config["serviceUuids"] as? List<String> ?: emptyList()
        if (serviceUuids.isEmpty()) return emptyList()
        return serviceUuids.mapNotNull { uuid ->
            runCatching {
                ScanFilter.Builder()
                    .setServiceUuid(ParcelUuid.fromString(uuid))
                    .build()
            }.getOrNull()
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun buildSettings(config: Map<String, Any?>): ScanSettings {
        val android = config["android"] as? Map<String, Any?> ?: emptyMap()
        val builder = ScanSettings.Builder()

        (android["scanMode"] as? Number)?.let { builder.setScanMode(it.toInt()) }
        (android["callbackType"] as? Number)?.let { builder.setCallbackType(it.toInt()) }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            (android["matchMode"] as? Number)?.let { builder.setMatchMode(it.toInt()) }
            (android["numOfMatches"] as? Number)?.let {
                builder.setNumOfMatches(it.toInt())
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            (android["legacy"] as? Boolean)?.let { builder.setLegacy(it) }
            (android["phy"] as? Number)?.let { builder.setPhy(it.toInt()) }
        }

        (config["reportDelayMillis"] as? Number)?.let {
            builder.setReportDelay(it.toLong())
        }

        return builder.build()
    }

    private fun bluetoothAdapter(): BluetoothAdapter? {
        val manager =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        return manager?.adapter
    }

    fun dispose() {
        stopScan()
    }
}
