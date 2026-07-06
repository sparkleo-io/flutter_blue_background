package com.sparkleo.flutter_blue_background.flutter_blue_background

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** FlutterBlueBackgroundPlugin */
class FlutterBlueBackgroundPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var scanResultsChannel: EventChannel
    private lateinit var adapterStateChannel: EventChannel
    private lateinit var connectionStateChannel: EventChannel
    private lateinit var characteristicValuesChannel: EventChannel
    private lateinit var context: Context
    private var adapterStateStreamHandler: BleAdapterStateStreamHandler? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        FbbLog.debug("onAttachedToEngine")

        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_blue_background")
        channel.setMethodCallHandler(this)

        scanResultsChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "flutter_blue_background/scan_results",
        )
        scanResultsChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                ScanResultDispatcher.setSink(events)
            }

            override fun onCancel(arguments: Any?) {
                ScanResultDispatcher.setSink(null)
            }
        })

        adapterStateStreamHandler = BleAdapterStateStreamHandler(context)
        adapterStateChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "flutter_blue_background/adapter_state",
        )
        adapterStateChannel.setStreamHandler(adapterStateStreamHandler)

        connectionStateChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "flutter_blue_background/connection_state",
        )
        connectionStateChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                ConnectionStateDispatcher.setSink(events)
            }

            override fun onCancel(arguments: Any?) {
                ConnectionStateDispatcher.setSink(null)
            }
        })

        characteristicValuesChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "flutter_blue_background/characteristic_values",
        )
        characteristicValuesChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                CharacteristicValueDispatcher.setSink(events)
            }

            override fun onCancel(arguments: Any?) {
                CharacteristicValueDispatcher.setSink(null)
            }
        })
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        FbbLog.debug("onMethodCall: ${call.method}")
        when (call.method) {
            "setLogLevel" -> {
                val idx = call.arguments as? Int ?: FbbLogLevel.DEBUG.ordinal
                FbbLog.setLevel(idx)
                result.success(null)
            }
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "getAdapterState" -> {
                val state = BleAdapterState.getState(context)
                adapterStateStreamHandler?.refreshState()
                result.success(state)
            }
            "startService" -> {
                val title = call.argument<String>("notificationTitle")
                val content = call.argument<String>("notificationContent")
                startService(title, content, null, null)
                result.success(true)
            }
            "stopService" -> {
                stopService()
                result.success(true)
            }
            "isServiceRunning" -> {
                result.success(FlutterBlueBackgroundService.isRunning)
            }
            "startScan" -> {
                // Scanning runs inside the foreground service but must NOT start
                // it. The service is started only via startService(). If it is
                // not running, the scan is rejected.
                if (!FlutterBlueBackgroundService.isRunning) {
                    result.success(false)
                    return
                }
                if (!BleAdapterState.isReady(context)) {
                    result.success(false)
                    return
                }
                @Suppress("UNCHECKED_CAST")
                val config = (call.arguments as? Map<String, Any?>) ?: emptyMap()
                val json = ScanConfigCodec.encode(config)
                startService(null, null, FlutterBlueBackgroundService.ACTION_START_SCAN, json)
                result.success(true)
            }
            "stopScan" -> {
                if (FlutterBlueBackgroundService.isRunning) {
                    startService(null, null, FlutterBlueBackgroundService.ACTION_STOP_SCAN, null)
                } else {
                    ScanResultDispatcher.isScanning = false
                }
                result.success(true)
            }
            "isScanning" -> {
                result.success(isScanningState())
            }
            "getScanResults" -> {
                result.success(ScanResultDispatcher.snapshot())
            }
            "clearScanResults" -> {
                ScanResultDispatcher.clearCache()
                result.success(true)
            }
            "connect" -> {
                if (!FlutterBlueBackgroundService.isRunning) {
                    result.success(false)
                    return
                }
                if (!BleAdapterState.isReady(context)) {
                    result.success(false)
                    return
                }
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                val deviceId = args["deviceId"] as? String
                @Suppress("UNCHECKED_CAST")
                val config = args["config"] as? Map<String, Any?> ?: emptyMap()
                if (deviceId.isNullOrEmpty()) {
                    result.success(false)
                    return
                }
                val json = ScanConfigCodec.encode(config)
                startConnectService(deviceId, json, null)
                result.success(true)
            }
            "disconnect" -> {
                val deviceId = call.argument<String>("deviceId")
                @Suppress("UNCHECKED_CAST")
                val config = call.argument<Map<String, Any?>>("config") ?: emptyMap()
                if (deviceId.isNullOrEmpty()) {
                    result.success(false)
                    return
                }
                if (FlutterBlueBackgroundService.isRunning) {
                    val json = ScanConfigCodec.encode(config)
                    startConnectService(deviceId, null, json)
                } else {
                    BleConnectorHolder.connector?.disconnect(deviceId, config)
                }
                result.success(true)
            }
            "getConnectionState" -> {
                val deviceId = call.argument<String>("deviceId")
                if (deviceId.isNullOrEmpty()) {
                    result.success("disconnected")
                    return
                }
                val state = BleConnectorHolder.connector?.getConnectionState(deviceId)
                    ?: ConnectionStateDispatcher.getState(deviceId)
                result.success(state)
            }
            "getConnectedDevices" -> {
                val devices = BleConnectorHolder.connector?.getConnectedDeviceIds()
                    ?: ConnectionStateDispatcher.getConnectedDeviceIds()
                result.success(devices)
            }
            "requestMtu" -> {
                val deviceId = call.argument<String>("deviceId")
                val mtu = call.argument<Int>("mtu") ?: 512
                if (deviceId.isNullOrEmpty() || !BleAdapterState.isReady(context)) {
                    result.success(23)
                    return
                }
                val negotiated = BleConnectorHolder.connector?.requestMtu(deviceId, mtu) ?: 23
                result.success(negotiated)
            }
            "requestConnectionPriority" -> {
                val deviceId = call.argument<String>("deviceId")
                val priority = call.argument<Int>("priority") ?: 0
                if (!deviceId.isNullOrEmpty()) {
                    BleConnectorHolder.connector?.requestConnectionPriority(deviceId, priority)
                }
                result.success(null)
            }
            "discoverServices" -> {
                val deviceId = call.argument<String>("deviceId")
                val timeoutMillis = call.argument<Int>("timeoutMillis")?.toLong() ?: 15_000L
                val subscribe = call.argument<Boolean>("subscribeToServicesChanged") ?: true
                if (deviceId.isNullOrEmpty() || !BleAdapterState.isReady(context)) {
                    result.success(emptyList<Any>())
                    return
                }
                val services = BleConnectorHolder.connector?.discoverServices(
                    deviceId,
                    timeoutMillis,
                    subscribe,
                ) ?: emptyList()
                result.success(services)
            }
            "readCharacteristic" -> {
                val args = characteristicArgs(call) ?: run {
                    result.success(gattErrorMap("Invalid arguments"))
                    return
                }
                val timeout = call.argument<Int>("timeoutMillis")?.toLong() ?: 15_000L
                val connector = BleConnectorHolder.connector
                if (connector == null || !FlutterBlueBackgroundService.isRunning) {
                    result.success(gattErrorMap("Background service is not running"))
                    return
                }
                result.success(
                    connector.readCharacteristic(
                        args.deviceId,
                        args.serviceUuid,
                        args.characteristicUuid,
                        args.instanceId,
                        timeout,
                    ),
                )
            }
            "writeCharacteristic" -> {
                val args = characteristicArgs(call) ?: run {
                    result.success(gattErrorMap("Invalid arguments"))
                    return
                }
                val value = parseByteArray(call, "value")
                val withoutResponse = call.argument<Boolean>("withoutResponse") ?: false
                val timeout = call.argument<Int>("timeoutMillis")?.toLong() ?: 15_000L
                val connector = BleConnectorHolder.connector
                if (connector == null || !FlutterBlueBackgroundService.isRunning) {
                    result.success(gattErrorMap("Background service is not running"))
                    return
                }
                result.success(
                    connector.writeCharacteristic(
                        args.deviceId,
                        args.serviceUuid,
                        args.characteristicUuid,
                        args.instanceId,
                        value,
                        withoutResponse,
                        timeout,
                    ),
                )
            }
            "setNotifyValue" -> {
                val args = characteristicArgs(call) ?: run {
                    result.success(gattErrorMap("Invalid arguments"))
                    return
                }
                val enable = call.argument<Boolean>("enable") ?: false
                val forceIndications = call.argument<Boolean>("forceIndications") ?: false
                val timeout = call.argument<Int>("timeoutMillis")?.toLong() ?: 15_000L
                val connector = BleConnectorHolder.connector
                if (connector == null || !FlutterBlueBackgroundService.isRunning) {
                    result.success(gattErrorMap("Background service is not running"))
                    return
                }
                result.success(
                    connector.setNotifyValue(
                        args.deviceId,
                        args.serviceUuid,
                        args.characteristicUuid,
                        args.instanceId,
                        enable,
                        forceIndications,
                        timeout,
                    ),
                )
            }
            else -> result.notImplemented()
        }
    }

    private fun isScanningState(): Boolean {
        if (ScanResultDispatcher.isScanning) return true
        val prefs = context.getSharedPreferences(
            FlutterBlueBackgroundService.PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        return prefs.getBoolean(FlutterBlueBackgroundService.KEY_SCAN_ENABLED, false)
    }

    private fun startService(
        title: String?,
        content: String?,
        action: String?,
        scanConfigJson: String?,
    ) {
        val serviceIntent = Intent(context, FlutterBlueBackgroundService::class.java).apply {
            action?.let { this.action = it }
            title?.let { putExtra(FlutterBlueBackgroundService.EXTRA_NOTIFICATION_TITLE, it) }
            content?.let { putExtra(FlutterBlueBackgroundService.EXTRA_NOTIFICATION_CONTENT, it) }
            scanConfigJson?.let { putExtra(FlutterBlueBackgroundService.EXTRA_SCAN_CONFIG, it) }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }

    private fun startConnectService(
        deviceId: String,
        connectConfigJson: String?,
        disconnectConfigJson: String?,
    ) {
        val action = if (disconnectConfigJson != null) {
            FlutterBlueBackgroundService.ACTION_DISCONNECT
        } else {
            FlutterBlueBackgroundService.ACTION_CONNECT
        }
        val serviceIntent = Intent(context, FlutterBlueBackgroundService::class.java).apply {
            this.action = action
            putExtra(FlutterBlueBackgroundService.EXTRA_DEVICE_ID, deviceId)
            connectConfigJson?.let {
                putExtra(FlutterBlueBackgroundService.EXTRA_CONNECT_CONFIG, it)
            }
            disconnectConfigJson?.let {
                putExtra(FlutterBlueBackgroundService.EXTRA_DISCONNECT_CONFIG, it)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }

    private fun stopService() {
        FlutterBlueBackgroundService.markStopRequested()
        context.stopService(Intent(context, FlutterBlueBackgroundService::class.java))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        FbbLog.debug("onDetachedFromEngine")
        channel.setMethodCallHandler(null)
        scanResultsChannel.setStreamHandler(null)
        adapterStateChannel.setStreamHandler(null)
        connectionStateChannel.setStreamHandler(null)
        characteristicValuesChannel.setStreamHandler(null)
        adapterStateStreamHandler = null
        ScanResultDispatcher.setSink(null)
        ConnectionStateDispatcher.setSink(null)
        CharacteristicValueDispatcher.setSink(null)
    }

    private data class CharacteristicArgs(
        val deviceId: String,
        val serviceUuid: String,
        val characteristicUuid: String,
        val instanceId: Int,
    )

    private fun characteristicArgs(call: MethodCall): CharacteristicArgs? {
        val deviceId = call.argument<String>("deviceId") ?: return null
        val serviceUuid = call.argument<String>("serviceUuid") ?: return null
        val characteristicUuid = call.argument<String>("characteristicUuid") ?: return null
        val instanceId = call.argument<Int>("instanceId") ?: 0
        if (deviceId.isEmpty() || serviceUuid.isEmpty() || characteristicUuid.isEmpty()) {
            return null
        }
        return CharacteristicArgs(deviceId, serviceUuid, characteristicUuid, instanceId)
    }

    private fun gattErrorMap(message: String): Map<String, Any?> = mapOf(
        "success" to false,
        "errorMessage" to "FBB: $message",
    )

    private fun parseByteArray(call: MethodCall, key: String): ByteArray {
        val raw = call.argument<Any>(key) ?: return ByteArray(0)
        return when (raw) {
            is ByteArray -> raw
            is List<*> -> raw.mapNotNull { (it as? Number)?.toInt()?.and(0xFF) }
                .map { it.toByte() }
                .toByteArray()
            else -> ByteArray(0)
        }
    }
}
