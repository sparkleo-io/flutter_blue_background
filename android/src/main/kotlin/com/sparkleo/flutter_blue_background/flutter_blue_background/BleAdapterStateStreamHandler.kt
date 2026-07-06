package com.sparkleo.flutter_blue_background.flutter_blue_background

import android.bluetooth.BluetoothAdapter
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Streams Bluetooth adapter state changes to Dart.
 *
 * The [BroadcastReceiver] is registered in [onListen] and unregistered in
 * [onCancel] so it never leaks beyond the EventChannel subscription lifetime.
 */
class BleAdapterStateStreamHandler(
    private val context: Context,
) : EventChannel.StreamHandler {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null
    private var lastEmittedState: String? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        emitCurrentState()

        val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        val broadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (intent?.action == BluetoothAdapter.ACTION_STATE_CHANGED) {
                    emitCurrentState()
                }
            }
        }
        receiver = broadcastReceiver
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(
                broadcastReceiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED,
            )
        } else {
            @Suppress("DEPRECATION")
            context.registerReceiver(broadcastReceiver, filter)
        }
    }

    override fun onCancel(arguments: Any?) {
        receiver?.let {
            runCatching { context.unregisterReceiver(it) }
        }
        receiver = null
        eventSink = null
    }

    private fun emitCurrentState() {
        val sink = eventSink ?: return
        val state = BleAdapterState.getState(context)
        if (state == lastEmittedState) return
        lastEmittedState = state
        mainHandler.post { sink.success(state) }
    }

    /** Re-emits the current adapter state when it changed (e.g. after permissions). */
    fun refreshState() {
        emitCurrentState()
    }
}
