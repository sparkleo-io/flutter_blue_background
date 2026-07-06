package com.sparkleo.flutter_blue_background.flutter_blue_background

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Streams GATT characteristic value events (read, write, notification) to Dart.
 */
object CharacteristicValueDispatcher {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val lock = Any()

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    @Volatile
    private var sinkGeneration = 0

    private val cache = ArrayList<Map<String, Any?>>()
    private const val MAX_CACHE = 64

    fun setSink(sink: EventChannel.EventSink?) {
        if (sink == null) {
            eventSink = null
            sinkGeneration++
            return
        }
        eventSink = sink
        val generation = sinkGeneration
        val snapshot = synchronized(lock) { cache.toList() }
        mainHandler.post {
            if (eventSink === sink && generation == sinkGeneration) {
                snapshot.forEach { sink.success(it) }
            }
        }
    }

    fun emit(event: Map<String, Any?>) {
        synchronized(lock) {
            cache.add(event)
            while (cache.size > MAX_CACHE) {
                cache.removeAt(0)
            }
        }
        val sink = eventSink ?: return
        val generation = sinkGeneration
        mainHandler.post {
            if (eventSink === sink && generation == sinkGeneration) {
                sink.success(event)
            }
        }
    }

    fun reset() = synchronized(lock) { cache.clear() }
}
