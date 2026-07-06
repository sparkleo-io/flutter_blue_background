package com.sparkleo.flutter_blue_background.flutter_blue_background

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Process-wide bridge between the service-owned [BleScanner] and the Flutter
 * [EventChannel].
 *
 * The scanner runs inside [FlutterBlueBackgroundService], whose lifetime is
 * independent of the Flutter engine. When the app is swiped away from recents
 * the engine (and its event sink) is torn down, but the foreground service —
 * and therefore this singleton and its result cache — stays alive in the same
 * process. When a fresh engine attaches, the cached results are replayed so the
 * UI can catch up on whatever was discovered while it was gone.
 */
object ScanResultDispatcher {

    private const val MAX_CACHE_SIZE = 256

    private val mainHandler = Handler(Looper.getMainLooper())
    private val lock = Any()

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    /** Bumped whenever the sink is detached so stale handler posts are ignored. */
    @Volatile
    private var sinkGeneration = 0

    /** Latest advertisement per deviceId; LRU-evicted when [MAX_CACHE_SIZE] is hit. */
    private val cache = object : LinkedHashMap<String, Map<String, Any?>>(MAX_CACHE_SIZE, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Map<String, Any?>>?): Boolean {
            return size > MAX_CACHE_SIZE
        }
    }

    @Volatile
    var isScanning: Boolean = false

    /**
     * Attaches (or detaches when null) the Flutter event sink. On attach, the
     * cached results are replayed so a newly created engine is brought up to
     * date.
     */
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

    fun emit(result: Map<String, Any?>) {
        val id = result["deviceId"] as? String ?: return
        synchronized(lock) {
            cache.remove(id)
            cache[id] = result
        }
        val sink = eventSink ?: return
        val generation = sinkGeneration
        mainHandler.post {
            if (eventSink === sink && generation == sinkGeneration) {
                sink.success(result)
            }
        }
    }

    fun error(code: String, message: String?) {
        val sink = eventSink ?: return
        val generation = sinkGeneration
        mainHandler.post {
            if (eventSink === sink && generation == sinkGeneration) {
                sink.error(code, message, null)
            }
        }
    }

    fun snapshot(): List<Map<String, Any?>> = synchronized(lock) { cache.values.toList() }

    fun clearCache() = synchronized(lock) { cache.clear() }

    /** Clears scan state when the service is intentionally stopped. */
    fun resetScanState() {
        synchronized(lock) { cache.clear() }
        isScanning = false
    }
}

/**
 * Minimal JSON <-> Map codec used to pass a scan config through an [android.content.Intent]
 * and persist it across a START_STICKY restart. The config only contains
 * primitives, strings, lists and nested maps, so this stays simple.
 */
object ScanConfigCodec {

    fun encode(map: Map<String, Any?>): String = toJsonObject(map).toString()

    fun decode(json: String): Map<String, Any?> =
        runCatching { fromJsonObject(JSONObject(json)) }.getOrDefault(emptyMap())

    private fun toJsonObject(map: Map<String, Any?>): JSONObject {
        val obj = JSONObject()
        for ((key, value) in map) {
            obj.put(key, toJsonValue(value))
        }
        return obj
    }

    private fun toJsonValue(value: Any?): Any {
        return when (value) {
            null -> JSONObject.NULL
            is Map<*, *> -> {
                val obj = JSONObject()
                for ((k, v) in value) obj.put(k.toString(), toJsonValue(v))
                obj
            }
            is List<*> -> {
                val arr = JSONArray()
                for (item in value) arr.put(toJsonValue(item))
                arr
            }
            else -> value
        }
    }

    private fun fromJsonObject(obj: JSONObject): Map<String, Any?> {
        val map = HashMap<String, Any?>()
        val keys = obj.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            map[key] = fromJsonValue(obj.get(key))
        }
        return map
    }

    private fun fromJsonValue(value: Any?): Any? {
        return when (value) {
            JSONObject.NULL -> null
            is JSONObject -> fromJsonObject(value)
            is JSONArray -> (0 until value.length()).map { fromJsonValue(value.get(it)) }
            else -> value
        }
    }
}
