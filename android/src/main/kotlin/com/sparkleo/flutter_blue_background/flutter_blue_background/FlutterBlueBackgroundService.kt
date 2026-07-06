package com.sparkleo.flutter_blue_background.flutter_blue_background

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * A long-running foreground service that keeps the app alive in the background.
 *
 * The service is intentionally generic: it only owns the foreground lifecycle
 * (notification, wake lock and a periodic keep-alive). BLE / business logic is
 * meant to be layered on top later.
 */
class FlutterBlueBackgroundService : Service() {

    companion object {
        const val CHANNEL_ID = "flutter_blue_background_channel"
        const val NOTIFICATION_ID = 4242

        const val PREFS_NAME = "flutter_blue_background_prefs"
        const val KEY_SERVICE_ENABLED = "service_enabled"
        const val KEY_NOTIFICATION_TITLE = "notification_title"
        const val KEY_NOTIFICATION_CONTENT = "notification_content"
        const val KEY_SCAN_ENABLED = "scan_enabled"
        const val KEY_SCAN_CONFIG = "scan_config"

        const val EXTRA_NOTIFICATION_TITLE = "notification_title"
        const val EXTRA_NOTIFICATION_CONTENT = "notification_content"
        const val EXTRA_SCAN_CONFIG = "scan_config"
        const val EXTRA_DEVICE_ID = "device_id"
        const val EXTRA_CONNECT_CONFIG = "connect_config"
        const val EXTRA_DISCONNECT_CONFIG = "disconnect_config"

        // Intent actions used by the plugin to drive the service.
        const val ACTION_START_SCAN = "com.sparkleo.flutter_blue_background.START_SCAN"
        const val ACTION_STOP_SCAN = "com.sparkleo.flutter_blue_background.STOP_SCAN"
        const val ACTION_CONNECT = "com.sparkleo.flutter_blue_background.CONNECT"
        const val ACTION_DISCONNECT = "com.sparkleo.flutter_blue_background.DISCONNECT"

        // Periodic keep-alive interval. Re-acquires the wake lock and refreshes
        // the notification so aggressive OEM power managers are less likely to
        // silently kill the service.
        private const val KEEP_ALIVE_INTERVAL_MS = 300_000L

        // Wake lock is refreshed on each keep-alive tick so it cannot be held
        // indefinitely if the service fails to tear down cleanly.
        private const val WAKE_LOCK_TIMEOUT_MS = KEEP_ALIVE_INTERVAL_MS * 2

        private const val DEFAULT_NOTIFICATION_TITLE = "Background service"
        private const val DEFAULT_NOTIFICATION_CONTENT = "Running in the background"

        @Volatile
        var isRunning: Boolean = false
            private set

        /** Set when the app explicitly asks the service to stop. */
        @Volatile
        private var isStopRequested: Boolean = false

        fun markStopRequested() {
            isStopRequested = true
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null
    private var keepAliveRunnable: Runnable? = null
    private var scanTimeoutRunnable: Runnable? = null
    private var adapterStateReceiver: BroadcastReceiver? = null

    private var notificationTitle: String = DEFAULT_NOTIFICATION_TITLE
    private var notificationContent: String = DEFAULT_NOTIFICATION_CONTENT

    private lateinit var bleScanner: BleScanner
    private lateinit var bleConnector: BleConnector

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        isStopRequested = false
        bleScanner = BleScanner(applicationContext)
        bleConnector = BleConnector(applicationContext)
        BleConnectorHolder.connector = bleConnector
        createNotificationChannel()
        acquireWakeLock()
        registerAdapterStateReceiver()
        FbbLog.debug("Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        notificationTitle = intent?.getStringExtra(EXTRA_NOTIFICATION_TITLE)
            ?: prefs.getString(KEY_NOTIFICATION_TITLE, DEFAULT_NOTIFICATION_TITLE)
            ?: DEFAULT_NOTIFICATION_TITLE
        notificationContent = intent?.getStringExtra(EXTRA_NOTIFICATION_CONTENT)
            ?: prefs.getString(KEY_NOTIFICATION_CONTENT, DEFAULT_NOTIFICATION_CONTENT)
            ?: DEFAULT_NOTIFICATION_CONTENT

        // Persist so a boot restart can recreate the same notification.
        prefs.edit()
            .putBoolean(KEY_SERVICE_ENABLED, true)
            .putString(KEY_NOTIFICATION_TITLE, notificationTitle)
            .putString(KEY_NOTIFICATION_CONTENT, notificationContent)
            .apply()

        startInForeground()
        startKeepAlive()

        handleScanCommand(intent, prefs)
        handleConnectCommand(intent)

        when (intent?.action) {
            ACTION_START_SCAN -> FbbLog.debug("Scan start command")
            ACTION_STOP_SCAN -> FbbLog.debug("Scan stop command")
            ACTION_CONNECT -> FbbLog.debug("Connect command")
            ACTION_DISCONNECT -> FbbLog.debug("Disconnect command")
            else -> FbbLog.verbose("onStartCommand (notification/config update)")
        }
        // START_STICKY so the system recreates the service if it is killed.
        return START_STICKY
    }

    /**
     * Applies the scan-related part of an incoming command:
     * - [ACTION_STOP_SCAN] stops scanning and clears the persisted config.
     * - [ACTION_START_SCAN] starts scanning with the supplied config and
     *   persists it so it can be resumed after a START_STICKY restart.
     * - A null intent (system restart) resumes a previously persisted scan.
     */
    private fun handleScanCommand(intent: Intent?, prefs: android.content.SharedPreferences) {
        when (intent?.action) {
            ACTION_STOP_SCAN -> {
                cancelScanTimeout()
                bleScanner.stopScan()
                prefs.edit()
                    .putBoolean(KEY_SCAN_ENABLED, false)
                    .remove(KEY_SCAN_CONFIG)
                    .apply()
            }

            ACTION_START_SCAN -> {
                val json = intent.getStringExtra(EXTRA_SCAN_CONFIG)
                if (json != null) {
                    prefs.edit()
                        .putBoolean(KEY_SCAN_ENABLED, true)
                        .putString(KEY_SCAN_CONFIG, json)
                        .apply()
                    val config = ScanConfigCodec.decode(json)
                    bleScanner.startScan(config)
                    scheduleScanTimeout(config)
                }
            }

            else -> {
                // Null intent (system restart) or a plain start: resume scan if
                // one was active.
                if (prefs.getBoolean(KEY_SCAN_ENABLED, false) && !bleScanner.isScanning) {
                    val json = prefs.getString(KEY_SCAN_CONFIG, null)
                    if (json != null) {
                        val config = ScanConfigCodec.decode(json)
                        bleScanner.startScan(config)
                        scheduleScanTimeout(config)
                    }
                }
            }
        }
    }

    /**
     * Schedules an automatic scan stop after `timeoutMillis` if the config
     * specifies one. A null/zero timeout means "scan until stopped".
     */
    private fun scheduleScanTimeout(config: Map<String, Any?>) {
        cancelScanTimeout()
        val timeoutMillis = (config["timeoutMillis"] as? Number)?.toLong() ?: return
        if (timeoutMillis <= 0L) return

        val runnable = Runnable {
            FbbLog.debug("Scan timeout reached; stopping scan")
            bleScanner.stopScan()
            // Clear the persisted scan so a later service restart does not resume
            // a scan whose timed window already elapsed.
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_SCAN_ENABLED, false)
                .remove(KEY_SCAN_CONFIG)
                .apply()
            scanTimeoutRunnable = null
        }
        scanTimeoutRunnable = runnable
        handler.postDelayed(runnable, timeoutMillis)
    }

    private fun cancelScanTimeout() {
        scanTimeoutRunnable?.let { handler.removeCallbacks(it) }
        scanTimeoutRunnable = null
    }

    /**
     * Listens for the system Bluetooth adapter turning off so the running scan
     * can be stopped.
     *
     * Without this, toggling Bluetooth off does NOT stop the LE scan: Android
     * may keep the radio in the hidden `BLE_ON` sub-state, so the scan callback
     * keeps firing (spamming "BT not enabled. Cannot get Remote Device name" and
     * burning CPU under the wake lock). Turning Bluetooth back on does NOT
     * auto-resume — the caller must start a new scan explicitly.
     */
    private fun registerAdapterStateReceiver() {
        if (adapterStateReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (intent?.action != BluetoothAdapter.ACTION_STATE_CHANGED) return
                when (intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)) {
                    BluetoothAdapter.STATE_TURNING_OFF, BluetoothAdapter.STATE_OFF ->
                        onBluetoothOff()
                }
            }
        }
        adapterStateReceiver = receiver
        val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, filter)
        }
    }

    private fun unregisterAdapterStateReceiver() {
        adapterStateReceiver?.let { runCatching { unregisterReceiver(it) } }
        adapterStateReceiver = null
    }

    /**
     * Stops the active scan and clears the persisted scan intent so it does not
     * resume — neither when Bluetooth comes back on nor after a START_STICKY
     * restart. `isScanning()` reports false afterwards.
     */
    private fun onBluetoothOff() {
        if (bleScanner.isScanning) {
            FbbLog.info("Bluetooth turned off; stopping scan")
            cancelScanTimeout()
            bleScanner.stopScan()
            ScanResultDispatcher.isScanning = false
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_SCAN_ENABLED, false)
                .remove(KEY_SCAN_CONFIG)
                .apply()
        }

        if (::bleConnector.isInitialized) {
            FbbLog.info("Bluetooth turned off; disconnecting GATT clients")
            bleConnector.onBluetoothAdapterOff()
            BleConnectorHolder.connector = bleConnector
        }
    }

    private fun handleConnectCommand(intent: Intent?) {
        if (!::bleConnector.isInitialized) return
        when (intent?.action) {
            ACTION_CONNECT -> {
                if (!BleAdapterState.isReady(applicationContext)) {
                    FbbLog.warning("Ignoring connect — Bluetooth adapter not ready")
                    return
                }
                val deviceId = intent.getStringExtra(EXTRA_DEVICE_ID) ?: return
                val json = intent.getStringExtra(EXTRA_CONNECT_CONFIG) ?: return
                val config = ScanConfigCodec.decode(json)
                bleConnector.connect(deviceId, config)
            }

            ACTION_DISCONNECT -> {
                val deviceId = intent.getStringExtra(EXTRA_DEVICE_ID) ?: return
                val json = intent.getStringExtra(EXTRA_DISCONNECT_CONFIG)
                val config = json?.let { ScanConfigCodec.decode(it) } ?: emptyMap()
                bleConnector.disconnect(deviceId, config)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Keep running even when the app is swiped away from recents.
        if (wakeLock?.isHeld != true) {
            acquireWakeLock()
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        FbbLog.debug("Service destroyed (stopRequested=$isStopRequested)")
        stopKeepAlive()
        cancelScanTimeout()
        unregisterAdapterStateReceiver()
        releaseWakeLock()

        // Always release the BluetoothLeScanner callback so we do not leak scan
        // registrations when the service instance is torn down. A START_STICKY
        // restart will resume scanning from persisted prefs in onStartCommand.
        if (::bleScanner.isInitialized) {
            bleScanner.dispose()
        }

        if (::bleConnector.isInitialized) {
            bleConnector.dispose()
            BleConnectorHolder.connector = null
        }

        if (isStopRequested) {
            ScanResultDispatcher.resetScanState()
            ConnectionStateDispatcher.reset()
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_SERVICE_ENABLED, false)
                .putBoolean(KEY_SCAN_ENABLED, false)
                .remove(KEY_SCAN_CONFIG)
                .apply()
        }

        isRunning = false
        super.onDestroy()
    }

    private fun startInForeground() {
        val notification = buildNotification(notificationTitle, notificationContent)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Background Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the app running in the background"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
                enableLights(false)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(title: String, content: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = launchIntent?.let {
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            PendingIntent.getActivity(this, 0, it, flags)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(resolveSmallIcon())
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setDefaults(0)
            .build()
    }

    /**
     * Prefer the host app's launcher icon and fall back to a platform icon so
     * the plugin does not need to bundle drawable resources.
     */
    private fun resolveSmallIcon(): Int {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            if (appInfo.icon != 0) appInfo.icon else android.R.drawable.ic_menu_info_details
        } catch (e: Exception) {
            android.R.drawable.ic_menu_info_details
        }
    }

    private fun updateNotification() {
        val notification = buildNotification(notificationTitle, notificationContent)
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, notification)
    }

    private fun acquireWakeLock() {
        if (wakeLock == null) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "FlutterBlueBackground::ServiceWakeLock"
            ).apply {
                setReferenceCounted(false)
            }
        }
        wakeLock?.let { lock ->
            if (lock.isHeld) {
                lock.release()
            }
            lock.acquire(WAKE_LOCK_TIMEOUT_MS)
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        wakeLock = null
    }

    private fun startKeepAlive() {
        stopKeepAlive()
        keepAliveRunnable = object : Runnable {
            override fun run() {
                if (wakeLock?.isHeld != true) {
                    acquireWakeLock()
                }
                updateNotification()
                handler.postDelayed(this, KEEP_ALIVE_INTERVAL_MS)
            }
        }
        handler.postDelayed(keepAliveRunnable!!, KEEP_ALIVE_INTERVAL_MS)
    }

    private fun stopKeepAlive() {
        keepAliveRunnable?.let { handler.removeCallbacks(it) }
        keepAliveRunnable = null
    }
}
