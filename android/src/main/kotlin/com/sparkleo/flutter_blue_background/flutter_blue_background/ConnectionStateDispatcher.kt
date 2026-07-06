package com.sparkleo.flutter_blue_background.flutter_blue_background

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Process-wide bridge between [BleConnector] and the Flutter connection state
 * [EventChannel], mirroring [ScanResultDispatcher].
 */
object ConnectionStateDispatcher {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val lock = Any()

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    @Volatile
    private var sinkGeneration = 0

    /** Latest state event per deviceId. */
    private val cache = LinkedHashMap<String, Map<String, Any?>>()

    fun setSink(sink: EventChannel.EventSink?) {
        if (sink == null) {
            eventSink = null
            sinkGeneration++
            return
        }
        eventSink = sink
        val generation = sinkGeneration
        val snapshot = snapshot()
        mainHandler.post {
            if (eventSink === sink && generation == sinkGeneration) {
                snapshot.forEach { sink.success(it) }
            }
        }
    }

    fun emit(event: Map<String, Any?>) {
        val id = event["deviceId"] as? String ?: return
        synchronized(lock) {
            cache[id] = event
        }
        val sink = eventSink ?: return
        val generation = sinkGeneration
        mainHandler.post {
            if (eventSink === sink && generation == sinkGeneration) {
                sink.success(event)
            }
        }
    }

    fun getState(deviceId: String): String {
        synchronized(lock) {
            return cache[deviceId]?.get("state") as? String ?: "disconnected"
        }
    }

    fun getConnectedDeviceIds(): List<String> = synchronized(lock) {
        cache.filterValues { it["state"] == "connected" }.keys.toList()
    }

    fun snapshot(): List<Map<String, Any?>> = synchronized(lock) { cache.values.toList() }

    fun remove(deviceId: String) = synchronized(lock) { cache.remove(deviceId) }

    fun reset() = synchronized(lock) { cache.clear() }
}
