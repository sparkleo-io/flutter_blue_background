package com.sparkleo.flutter_blue_background.flutter_blue_background

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Owns active GATT connections inside [FlutterBlueBackgroundService].
 *
 * Connection state is mirrored to Flutter through [ConnectionStateDispatcher].
 */
class BleConnector(private val context: Context) {

    companion object {
        /** GAP service and Services Changed characteristic. */
        private val GAP_SERVICE_UUID = java.util.UUID.fromString(
            "00001801-0000-1000-8000-00805f9b34fb",
        )
        private val SERVICES_CHANGED_UUID = java.util.UUID.fromString(
            "00002a05-0000-1000-8000-00805f9b34fb",
        )
        private val CCCD_UUID = java.util.UUID.fromString(
            "00002902-0000-1000-8000-00805f9b34fb",
        )
    }

    private data class PendingCharacteristicOp(
        val type: String,
        val serviceUuid: String,
        val characteristicUuid: String,
        val instanceId: Int,
        val latch: CountDownLatch,
        var success: Boolean = false,
        var value: ByteArray? = null,
        var errorCode: Int? = null,
        var errorMessage: String? = null,
    )

    private val mainHandler = Handler(Looper.getMainLooper())
    private val sessions = ConcurrentHashMap<String, DeviceSession>()

    private data class DeviceSession(
        val deviceId: String,
        var gatt: BluetoothGatt? = null,
        var config: Map<String, Any?>? = null,
        var mtu: Int = 23,
        var connectTimestamp: Long = 0,
        var timeoutRunnable: Runnable? = null,
        var pendingDiscoverLatch: CountDownLatch? = null,
        var pendingDiscoverResult: List<Map<String, Any?>>? = null,
        var pendingMtuLatch: CountDownLatch? = null,
        var pendingMtuResult: Int? = null,
        var pendingCharOp: PendingCharacteristicOp? = null,
    )

    @SuppressLint("MissingPermission")
    fun connect(deviceId: String, config: Map<String, Any?>): Boolean {
        if (!BlePermissions.hasConnectPermission(context)) {
            FbbLog.warning("Missing BLUETOOTH_CONNECT permission")
            emitState(deviceId, "disconnected", errorMessage = "Missing Bluetooth permission")
            return false
        }

        if (!BleAdapterState.isReady(context)) {
            FbbLog.warning("Bluetooth adapter not ready")
            emitState(deviceId, "disconnected", errorMessage = "Bluetooth adapter is not ready")
            return false
        }

        val adapter = bluetoothAdapter() ?: run {
            emitState(deviceId, "disconnected", errorMessage = "Bluetooth adapter unavailable")
            return false
        }

        val autoConnect = config["autoConnect"] as? Boolean ?: false
        val existing = sessions[deviceId]
        if (existing?.gatt != null &&
            ConnectionStateDispatcher.getState(deviceId) == "connected"
        ) {
            FbbLog.debug("Already connected to $deviceId")
            return true
        }

        // Tear down any in-flight connection attempt first.
        disconnectInternal(deviceId, androidDelayMillis = 0, waitMs = 0)

        val android = config["android"] as? Map<String, Any?> ?: emptyMap()
        val transport = (android["transport"] as? Number)?.toInt()
            ?: BluetoothDevice.TRANSPORT_LE
        val phy = (android["phy"] as? Number)?.toInt()
            ?: BluetoothDevice.PHY_LE_1M_MASK

        val session = DeviceSession(deviceId = deviceId, config = config)
        sessions[deviceId] = session

        emitState(deviceId, "connecting", mtu = session.mtu)
        FbbLog.debug("connect: $deviceId autoConnect=$autoConnect transport=$transport")

        val device = runCatching { adapter.getRemoteDevice(deviceId) }.getOrNull()
        if (device == null) {
            emitState(deviceId, "disconnected", errorMessage = "Invalid device id")
            sessions.remove(deviceId)
            return false
        }

        val callback = createGattCallback(deviceId)
        val gatt = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                device.connectGatt(context, autoConnect, callback, transport, phy)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                device.connectGatt(context, autoConnect, callback, transport)
            } else {
                device.connectGatt(context, autoConnect, callback)
            }
        } catch (e: Exception) {
            FbbLog.error("connectGatt failed: ${e.message}")
            emitState(deviceId, "disconnected", errorMessage = e.message)
            sessions.remove(deviceId)
            return false
        }

        session.gatt = gatt
        session.connectTimestamp = System.currentTimeMillis()

        if (!autoConnect) {
            val timeoutMillis = (config["timeoutMillis"] as? Number)?.toLong()
                ?: 35_000L
            val runnable = Runnable {
                if (ConnectionStateDispatcher.getState(deviceId) != "connected") {
                    FbbLog.warning("Connection timeout for $deviceId")
                    disconnectInternal(deviceId, androidDelayMillis = 0, waitMs = 0)
                    emitState(
                        deviceId,
                        "disconnected",
                        errorMessage = "Connection timeout",
                    )
                }
            }
            session.timeoutRunnable = runnable
            mainHandler.postDelayed(runnable, timeoutMillis)
        }

        return true
    }

    @SuppressLint("MissingPermission")
    fun disconnect(deviceId: String, config: Map<String, Any?>): Boolean {
        FbbLog.debug("disconnect: $deviceId")
        val androidDelay = (config["androidDelayMillis"] as? Number)?.toLong() ?: 2000L
        val waitMs = (config["timeoutMillis"] as? Number)?.toLong() ?: 35_000L
        disconnectInternal(deviceId, androidDelay, waitMs)
        return true
    }

    fun getConnectionState(deviceId: String): String =
        ConnectionStateDispatcher.getState(deviceId)

    fun getConnectedDeviceIds(): List<String> =
        ConnectionStateDispatcher.getConnectedDeviceIds()

    @SuppressLint("MissingPermission")
    fun requestMtu(deviceId: String, mtu: Int): Int {
        val session = sessions[deviceId] ?: return 23
        val gatt = session.gatt ?: return session.mtu
        if (!BlePermissions.hasConnectPermission(context)) return session.mtu

        val latch = CountDownLatch(1)
        session.pendingMtuLatch = latch
        session.pendingMtuResult = null

        val started = gatt.requestMtu(mtu.coerceIn(23, 517))
        if (!started) {
            session.pendingMtuLatch = null
            return session.mtu
        }

        latch.await(15, TimeUnit.SECONDS)
        session.pendingMtuLatch = null
        return session.pendingMtuResult ?: session.mtu
    }

    @SuppressLint("MissingPermission")
    fun requestConnectionPriority(deviceId: String, priority: Int): Boolean {
        val session = sessions[deviceId] ?: return false
        val gatt = session.gatt ?: return false
        if (!BlePermissions.hasConnectPermission(context)) return false

        val nativePriority = when (priority) {
            1 -> BluetoothGatt.CONNECTION_PRIORITY_HIGH
            2 -> BluetoothGatt.CONNECTION_PRIORITY_LOW_POWER
            else -> BluetoothGatt.CONNECTION_PRIORITY_BALANCED
        }
        return gatt.requestConnectionPriority(nativePriority)
    }

    @SuppressLint("MissingPermission")
    fun discoverServices(
        deviceId: String,
        timeoutMillis: Long,
        subscribeToServicesChanged: Boolean,
    ): List<Map<String, Any?>>? {
        val session = sessions[deviceId] ?: return null
        val gatt = session.gatt ?: return null
        if (ConnectionStateDispatcher.getState(deviceId) != "connected") return null
        if (!BlePermissions.hasConnectPermission(context)) return null

        session.config = (session.config ?: emptyMap()).toMutableMap().apply {
            put("subscribeToServicesChanged", subscribeToServicesChanged)
        }

        val latch = CountDownLatch(1)
        session.pendingDiscoverLatch = latch
        session.pendingDiscoverResult = null

        if (!gatt.discoverServices()) {
            session.pendingDiscoverLatch = null
            return null
        }

        latch.await(timeoutMillis.coerceAtLeast(1000), TimeUnit.MILLISECONDS)
        session.pendingDiscoverLatch = null
        return session.pendingDiscoverResult
    }

    @SuppressLint("MissingPermission")
    fun readCharacteristic(
        deviceId: String,
        serviceUuid: String,
        characteristicUuid: String,
        instanceId: Int,
        timeoutMillis: Long,
    ): Map<String, Any?> {
        val session = sessions[deviceId] ?: return gattError("Device not connected")
        val gatt = session.gatt ?: return gattError("GATT not available")
        if (ConnectionStateDispatcher.getState(deviceId) != "connected") {
            return gattError("Device not connected")
        }
        if (!BlePermissions.hasConnectPermission(context)) {
            return gattError("Missing Bluetooth permission")
        }

        val characteristic = findCharacteristic(gatt, serviceUuid, characteristicUuid, instanceId)
            ?: return gattError("Characteristic not found")

        val latch = CountDownLatch(1)
        val op = PendingCharacteristicOp(
            type = "read",
            serviceUuid = serviceUuid,
            characteristicUuid = characteristicUuid,
            instanceId = instanceId,
            latch = latch,
        )
        session.pendingCharOp = op

        if (!gatt.readCharacteristic(characteristic)) {
            session.pendingCharOp = null
            return gattError("readCharacteristic returned false")
        }

        latch.await(timeoutMillis.coerceAtLeast(1000), TimeUnit.MILLISECONDS)
        session.pendingCharOp = null
        return op.toResultMap()
    }

    @SuppressLint("MissingPermission")
    fun writeCharacteristic(
        deviceId: String,
        serviceUuid: String,
        characteristicUuid: String,
        instanceId: Int,
        value: ByteArray,
        withoutResponse: Boolean,
        timeoutMillis: Long,
    ): Map<String, Any?> {
        val session = sessions[deviceId] ?: return gattError("Device not connected")
        val gatt = session.gatt ?: return gattError("GATT not available")
        if (ConnectionStateDispatcher.getState(deviceId) != "connected") {
            return gattError("Device not connected")
        }
        if (!BlePermissions.hasConnectPermission(context)) {
            return gattError("Missing Bluetooth permission")
        }

        val characteristic = findCharacteristic(gatt, serviceUuid, characteristicUuid, instanceId)
            ?: return gattError("Characteristic not found")

        val writeType = if (withoutResponse) {
            BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
        } else {
            BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        }

        val latch = CountDownLatch(1)
        val op = PendingCharacteristicOp(
            type = "write",
            serviceUuid = serviceUuid,
            characteristicUuid = characteristicUuid,
            instanceId = instanceId,
            latch = latch,
        )
        session.pendingCharOp = op

        val started = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            gatt.writeCharacteristic(characteristic, value, writeType) ==
                android.bluetooth.BluetoothStatusCodes.SUCCESS
        } else {
            @Suppress("DEPRECATION")
            characteristic.writeType = writeType
            @Suppress("DEPRECATION")
            characteristic.value = value
            @Suppress("DEPRECATION")
            gatt.writeCharacteristic(characteristic)
        }

        if (!started) {
            session.pendingCharOp = null
            return gattError("writeCharacteristic returned false")
        }

        FbbLog.info(
            "writeCharacteristic: $characteristicUuid instanceId=$instanceId " +
                "withoutResponse=$withoutResponse bytes=${value.size} " +
                "hex=${value.joinToString(" ") { "%02x".format(it) }}",
        )

        // Match iOS / FBP: write-without-response is fire-and-forget at the ATT layer.
        if (withoutResponse) {
            op.success = true
            op.value = value
            session.pendingCharOp = null
            emitCharacteristicValue(
                deviceId,
                serviceUuid,
                characteristicUuid,
                instanceId,
                value,
                "write",
                true,
                null,
            )
            return op.toResultMap()
        }

        latch.await(timeoutMillis.coerceAtLeast(1000), TimeUnit.MILLISECONDS)
        session.pendingCharOp = null
        return op.toResultMap()
    }

    @SuppressLint("MissingPermission")
    fun setNotifyValue(
        deviceId: String,
        serviceUuid: String,
        characteristicUuid: String,
        instanceId: Int,
        enable: Boolean,
        forceIndications: Boolean,
        timeoutMillis: Long,
    ): Map<String, Any?> {
        val session = sessions[deviceId] ?: return gattError("Device not connected")
        val gatt = session.gatt ?: return gattError("GATT not available")
        if (ConnectionStateDispatcher.getState(deviceId) != "connected") {
            return gattError("Device not connected")
        }
        if (!BlePermissions.hasConnectPermission(context)) {
            return gattError("Missing Bluetooth permission")
        }

        val characteristic = findCharacteristic(gatt, serviceUuid, characteristicUuid, instanceId)
            ?: return gattError("Characteristic not found")

        val notificationRegistered = gatt.setCharacteristicNotification(characteristic, enable)
        FbbLog.info(
            "setNotifyValue: setCharacteristicNotification($characteristicUuid, enable=$enable) " +
                "→ $notificationRegistered",
        )
        if (!notificationRegistered) {
            return gattError("setCharacteristicNotification returned false")
        }

        val cccd = findCccdDescriptor(characteristic)
        if (cccd == null) {
            FbbLog.warning(
                "CCCD descriptor for characteristic not found: ${characteristic.uuid}",
            )
            if (enable) {
                return gattError(
                    "CCCD descriptor not found for characteristic ${characteristic.uuid}",
                )
            }
            return mapOf("success" to true, "cccdWritten" to false)
        }

        val props = characteristic.properties
        if (enable) {
            val canNotify = props and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0
            val canIndicate = props and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0
            if (!canNotify && !canIndicate) {
                return gattError(
                    "neither NOTIFY nor INDICATE properties are supported by this BLE characteristic",
                )
            }
            if (forceIndications && !canIndicate) {
                return gattError("INDICATE not supported by this BLE characteristic")
            }
        }

        // FBP: prefer notify over indicate unless forceIndications (iOS CoreBluetooth behaviour).
        val cccdValue = when {
            !enable -> BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
            forceIndications && props and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0 ->
                BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
            props and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0 ->
                BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            props and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0 ->
                BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
            else -> BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        }

        val latch = CountDownLatch(1)
        val op = PendingCharacteristicOp(
            type = "descriptor",
            serviceUuid = serviceUuid,
            characteristicUuid = characteristicUuid,
            instanceId = instanceId,
            latch = latch,
        )
        session.pendingCharOp = op

        val started = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            gatt.writeDescriptor(cccd, cccdValue) ==
                android.bluetooth.BluetoothStatusCodes.SUCCESS
        } else {
            @Suppress("DEPRECATION")
            cccd.value = cccdValue
            @Suppress("DEPRECATION")
            gatt.writeDescriptor(cccd)
        }

        if (!started) {
            session.pendingCharOp = null
            return gattError("writeDescriptor returned false")
        }

        FbbLog.info(
            "setNotifyValue: writing CCCD for $characteristicUuid " +
                "(enable=$enable, bytes=${cccdValue.joinToString(" ") { "%02x".format(it) }})",
        )

        latch.await(timeoutMillis.coerceAtLeast(1000), TimeUnit.MILLISECONDS)
        session.pendingCharOp = null
        val result = op.toResultMap().toMutableMap()
        result["cccdWritten"] = op.success
        return result
    }

    fun dispose() {
        forceDisconnectAll(reason = null)
    }

    /**
     * Called when the system Bluetooth adapter turns off. Emits disconnected
     * events immediately so Flutter UI stays in sync (unlike async GATT teardown).
     */
    fun onBluetoothAdapterOff() {
        forceDisconnectAll(reason = "Bluetooth turned off")
    }

    @SuppressLint("MissingPermission")
    private fun forceDisconnectAll(reason: String?) {
        for (deviceId in sessions.keys.toList()) {
            val session = sessions.remove(deviceId) ?: continue
            session.timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
            session.gatt?.let { gatt ->
                runCatching {
                    if (BlePermissions.hasConnectPermission(context)) {
                        gatt.disconnect()
                    }
                    gatt.close()
                }
            }
            emitState(
                deviceId,
                "disconnected",
                mtu = session.mtu,
                errorMessage = reason,
            )
        }
        sessions.clear()
        CharacteristicValueDispatcher.reset()
    }

    @SuppressLint("MissingPermission")
    private fun disconnectInternal(
        deviceId: String,
        androidDelayMillis: Long,
        waitMs: Long,
    ) {
        val session = sessions[deviceId] ?: return
        session.timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        session.timeoutRunnable = null

        val gatt = session.gatt
        if (gatt == null) {
            emitState(deviceId, "disconnected")
            sessions.remove(deviceId)
            return
        }

        val elapsed = System.currentTimeMillis() - session.connectTimestamp
        val delay = (androidDelayMillis - elapsed).coerceAtLeast(0)
        mainHandler.postDelayed({
            emitState(deviceId, "disconnecting", mtu = session.mtu)
            if (BlePermissions.hasConnectPermission(context)) {
                runCatching { gatt.disconnect() }
                runCatching { gatt.close() }
            }
            session.gatt = null
            emitState(deviceId, "disconnected", mtu = session.mtu)
            sessions.remove(deviceId)
            ConnectionStateDispatcher.remove(deviceId)
        }, if (waitMs <= 0) 0 else delay.coerceAtMost(waitMs))
    }

    private fun createGattCallback(deviceId: String): BluetoothGattCallback {
        return object : BluetoothGattCallback() {
            override fun onConnectionStateChange(
                gatt: BluetoothGatt,
                status: Int,
                newState: Int,
            ) {
                val session = sessions[deviceId] ?: return
                FbbLog.debug(
                    "onConnectionStateChange: $deviceId state=$newState status=$status",
                )
                when (newState) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        session.timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
                        session.timeoutRunnable = null
                        session.gatt = gatt
                        emitState(deviceId, "connected", mtu = session.mtu)

                        val config = session.config ?: emptyMap()
                        val android = config["android"] as? Map<String, Any?> ?: emptyMap()

                        if (!BlePermissions.hasConnectPermission(context)) return

                        val priority = (android["connectionPriority"] as? Number)?.toInt() ?: 0
                        requestConnectionPriority(deviceId, priority)

                        val autoConnect = config["autoConnect"] as? Boolean ?: false
                        val mtu = (android["mtu"] as? Number)?.toInt()
                        if (!autoConnect && mtu != null) {
                            gatt.requestMtu(mtu.coerceIn(23, 517))
                        } else if (config["discoverServicesOnConnect"] as? Boolean != false) {
                            gatt.discoverServices()
                        }
                    }

                    BluetoothProfile.STATE_DISCONNECTED -> {
                        session.timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
                        session.timeoutRunnable = null
                        runCatching { gatt.close() }
                        session.gatt = null
                        val message = if (status != BluetoothGatt.GATT_SUCCESS) {
                            "GATT status $status"
                        } else {
                            null
                        }
                        emitState(
                            deviceId,
                            "disconnected",
                            mtu = session.mtu,
                            errorMessage = message,
                            errorCode = if (status != BluetoothGatt.GATT_SUCCESS) status else null,
                        )
                        sessions.remove(deviceId)
                    }
                }
            }

            override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
                val session = sessions[deviceId] ?: return
                FbbLog.debug("onMtuChanged: $deviceId mtu=$mtu status=$status")
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    session.mtu = mtu
                    emitState(deviceId, "connected", mtu = mtu)
                }
                session.pendingMtuResult = session.mtu
                session.pendingMtuLatch?.countDown()

                val config = session.config ?: return
                if (config["discoverServicesOnConnect"] as? Boolean != false &&
                    session.pendingDiscoverLatch == null
                ) {
                    gatt.discoverServices()
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                val session = sessions[deviceId] ?: return
                val count = if (status == BluetoothGatt.GATT_SUCCESS) gatt.services.size else 0
                FbbLog.debug(
                    "onServicesDiscovered: $deviceId count=$count status=$status",
                )
                // FBP / Android: discoverServices() also discovers descriptors.
                val services = if (status == BluetoothGatt.GATT_SUCCESS) {
                    mapServices(gatt)
                } else {
                    emptyList()
                }

                session.pendingDiscoverResult = services
                session.pendingDiscoverLatch?.countDown()

                val subscribe = session.config?.get("subscribeToServicesChanged") as? Boolean
                    ?: true
                if (subscribe && status == BluetoothGatt.GATT_SUCCESS) {
                    subscribeServicesChanged(gatt)
                }
            }

            override fun onServiceChanged(gatt: BluetoothGatt) {
                FbbLog.info("onServiceChanged: ${gatt.device.address}")
                if (!BlePermissions.hasConnectPermission(context)) return
                gatt.discoverServices()
            }

            override fun onCharacteristicRead(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                value: ByteArray,
                status: Int,
            ) {
                handleCharacteristicRead(deviceId, characteristic, value, status)
            }

            @Deprecated("Deprecated in Java")
            override fun onCharacteristicRead(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                status: Int,
            ) {
                @Suppress("DEPRECATION")
                val value = characteristic.value ?: ByteArray(0)
                handleCharacteristicRead(deviceId, characteristic, value, status)
            }

            override fun onCharacteristicWrite(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                status: Int,
            ) {
                handleCharacteristicWrite(deviceId, characteristic, status)
            }

            override fun onCharacteristicChanged(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                value: ByteArray,
            ) {
                handleCharacteristicChanged(deviceId, characteristic, value)
            }

            @Deprecated("Deprecated in Java")
            override fun onCharacteristicChanged(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
            ) {
                @Suppress("DEPRECATION")
                handleCharacteristicChanged(deviceId, characteristic, characteristic.value ?: ByteArray(0))
            }

            override fun onDescriptorWrite(
                gatt: BluetoothGatt,
                descriptor: BluetoothGattDescriptor,
                status: Int,
            ) {
                val session = sessions[deviceId] ?: return
                val op = session.pendingCharOp ?: return
                if (op.type != "descriptor") return
                val characteristic = descriptor.characteristic ?: return
                if (!uuidMatches(op.serviceUuid, characteristic.service.uuid)) return
                if (!uuidMatches(op.characteristicUuid, characteristic.uuid)) return
                if (characteristicInstanceId(characteristic) != op.instanceId) return
                FbbLog.info(
                    "onDescriptorWrite: ${characteristic.uuid} status=$status " +
                        "(pending ${op.characteristicUuid})",
                )
                op.success = status == BluetoothGatt.GATT_SUCCESS
                if (!op.success) {
                    op.errorCode = status
                    op.errorMessage = "GATT status $status"
                }
                op.latch.countDown()
            }
        }
    }

    private fun findCccdDescriptor(
        characteristic: BluetoothGattCharacteristic,
    ): BluetoothGattDescriptor? {
        characteristic.descriptors.firstOrNull { it.uuid == CCCD_UUID }?.let { return it }
        characteristic.getDescriptor(CCCD_UUID)?.let { return it }
        // Some stacks omit CCCD from discovery; add it so writeDescriptor can enable notify.
        return runCatching {
            val descriptor = BluetoothGattDescriptor(
                CCCD_UUID,
                BluetoothGattDescriptor.PERMISSION_READ or
                    BluetoothGattDescriptor.PERMISSION_WRITE,
            )
            if (characteristic.addDescriptor(descriptor)) {
                descriptor
            } else {
                null
            }
        }.getOrNull()
    }

    @SuppressLint("MissingPermission")
    private fun subscribeServicesChanged(gatt: BluetoothGatt) {
        val service = gatt.getService(GAP_SERVICE_UUID) ?: return
        val characteristic = service.getCharacteristic(SERVICES_CHANGED_UUID) ?: return
        gatt.setCharacteristicNotification(characteristic, true)
        val descriptor = findCccdDescriptor(characteristic) ?: return
        descriptor.value = BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
        gatt.writeDescriptor(descriptor)
    }

    private fun mapServices(gatt: BluetoothGatt): List<Map<String, Any?>> {
        val filterUuids = (sessions[gatt.device.address]?.config?.get("serviceUuids")
            as? List<*>)?.mapNotNull { it?.toString() }?.toSet()

        return gatt.services.mapNotNull { service ->
            val uuid = service.uuid.toString()
            if (filterUuids != null && filterUuids.isNotEmpty() && uuid !in filterUuids) {
                return@mapNotNull null
            }
            mapOf(
                "uuid" to uuid,
                "characteristics" to service.characteristics.map { mapCharacteristic(it) },
            )
        }
    }

    private fun mapCharacteristic(
        characteristic: BluetoothGattCharacteristic,
    ): Map<String, Any?> {
        val props = mutableListOf<String>()
        val p = characteristic.properties
        if (p and BluetoothGattCharacteristic.PROPERTY_READ != 0) props.add("read")
        if (p and BluetoothGattCharacteristic.PROPERTY_WRITE != 0) props.add("write")
        if (p and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0) {
            props.add("writeWithoutResponse")
        }
        if (p and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) props.add("notify")
        if (p and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0) props.add("indicate")
        return mapOf(
            "uuid" to characteristic.uuid.toString(),
            "instanceId" to characteristicInstanceId(characteristic),
            "properties" to props,
            "descriptors" to characteristic.descriptors.map {
                mapOf("uuid" to it.uuid.toString())
            },
        )
    }

    private fun handleCharacteristicRead(
        deviceId: String,
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray,
        status: Int,
    ) {
        val session = sessions[deviceId] ?: return
        val serviceUuid = characteristic.service.uuid.toString()
        val charUuid = characteristic.uuid.toString()
        val instanceId = characteristicInstanceId(characteristic)
        val success = status == BluetoothGatt.GATT_SUCCESS

        emitCharacteristicValue(
            deviceId, serviceUuid, charUuid, instanceId, value, "read", success, status,
        )

        val op = session.pendingCharOp ?: return
        if (op.type != "read") return
        op.success = success
        op.value = if (success) value else null
        if (!success) {
            op.errorCode = status
            op.errorMessage = "GATT status $status"
        }
        op.latch.countDown()
    }

    private fun handleCharacteristicWrite(
        deviceId: String,
        characteristic: BluetoothGattCharacteristic,
        status: Int,
    ) {
        val session = sessions[deviceId] ?: return
        val serviceUuid = characteristic.service.uuid.toString()
        val charUuid = characteristic.uuid.toString()
        val instanceId = characteristicInstanceId(characteristic)
        val success = status == BluetoothGatt.GATT_SUCCESS
        @Suppress("DEPRECATION")
        val value = characteristic.value ?: ByteArray(0)

        emitCharacteristicValue(
            deviceId, serviceUuid, charUuid, instanceId, value, "write", success, status,
        )

        FbbLog.info(
            "onCharacteristicWrite: $charUuid status=$status len=${value.size}",
        )

        val op = session.pendingCharOp ?: return
        if (op.type != "write") return
        op.success = success
        op.value = value
        if (!success) {
            op.errorCode = status
            op.errorMessage = "GATT status $status"
        }
        op.latch.countDown()
    }

    private fun handleCharacteristicChanged(
        deviceId: String,
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray,
    ) {
        val hexPreview = value.take(32).joinToString(" ") { "%02x".format(it) }
        FbbLog.info(
            "onCharacteristicChanged: $deviceId ${characteristic.uuid} " +
                "len=${value.size} hex=$hexPreview",
        )
        emitCharacteristicValue(
            deviceId,
            characteristic.service.uuid.toString(),
            characteristic.uuid.toString(),
            characteristicInstanceId(characteristic),
            value,
            "notification",
            true,
            null,
        )
    }

    private fun emitCharacteristicValue(
        deviceId: String,
        serviceUuid: String,
        characteristicUuid: String,
        instanceId: Int,
        value: ByteArray,
        source: String,
        success: Boolean,
        errorCode: Int?,
    ) {
        val event = mutableMapOf<String, Any?>(
            "deviceId" to deviceId,
            "serviceUuid" to serviceUuid,
            "characteristicUuid" to characteristicUuid,
            "instanceId" to instanceId,
            "value" to value,
            "source" to source,
            "success" to success,
        )
        if (errorCode != null && !success) {
            event["errorCode"] = errorCode
            event["errorMessage"] = "GATT status $errorCode"
        }
        CharacteristicValueDispatcher.emit(event)
    }

    private fun findCharacteristic(
        gatt: BluetoothGatt,
        serviceUuid: String,
        characteristicUuid: String,
        instanceId: Int,
    ): BluetoothGattCharacteristic? {
        val service = gatt.services.firstOrNull { uuidMatches(serviceUuid, it.uuid) }
            ?: return null
        val matches = service.characteristics.filter { uuidMatches(characteristicUuid, it.uuid) }
        if (matches.isEmpty()) return null
        if (matches.size == 1) return matches[0]
        return matches.firstOrNull { characteristicInstanceId(it) == instanceId }
            ?: matches[0]
    }

    private fun uuidMatches(uuid: String, other: java.util.UUID): Boolean =
        normalizeUuid(uuid) == normalizeUuid(other.toString())

    private fun normalizeUuid(uuid: String): String = uuid.lowercase().replace("-", "")

    private fun characteristicInstanceId(characteristic: BluetoothGattCharacteristic): Int =
        runCatching { characteristic.instanceId }.getOrElse { 0 }

    private fun gattError(message: String): Map<String, Any?> = mapOf(
        "success" to false,
        "errorMessage" to "FBB: $message",
    )

    private fun PendingCharacteristicOp.toResultMap(): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>("success" to success)
        value?.let { map["value"] = it }
        errorCode?.let { map["errorCode"] = it }
        errorMessage?.let { map["errorMessage"] = if (it.startsWith("FBB:")) it else "FBB: $it" }
        if (!success && errorMessage == null) {
            map["errorMessage"] = "FBB: GATT operation failed"
        }
        return map
    }

    private fun emitState(
        deviceId: String,
        state: String,
        mtu: Int? = null,
        errorMessage: String? = null,
        errorCode: Int? = null,
    ) {
        val event = mutableMapOf<String, Any?>(
            "deviceId" to deviceId,
            "state" to state,
        )
        mtu?.let { event["mtu"] = it }
        errorMessage?.let { event["errorMessage"] = it }
        errorCode?.let { event["errorCode"] = it }
        ConnectionStateDispatcher.emit(event)
    }

    private fun bluetoothAdapter(): BluetoothAdapter? {
        val manager =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        return manager?.adapter
    }
}

/** Lets the plugin invoke GATT ops on the service-owned connector. */
object BleConnectorHolder {
    @Volatile
    var connector: BleConnector? = null
}
