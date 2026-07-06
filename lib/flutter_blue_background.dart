import 'dart:typed_data';

import 'flutter_blue_background_platform_interface.dart';
import 'src/ble_operation_mutex.dart';
import 'src/fbb_log_level.dart';
import 'src/fbb_logger.dart';
import 'src/models/ble_adapter_state.dart';
import 'src/models/ble_connection_state.dart';
import 'src/models/ble_characteristic_id.dart';
import 'src/models/ble_characteristic_value_event.dart';
import 'src/models/ble_gatt_service.dart';
import 'src/models/ble_scan_result.dart';
import 'src/models/connect_config.dart';
import 'src/models/scan_config.dart';

export 'src/fbb_exception.dart';
export 'src/fbb_log_level.dart';
export 'src/models/ble_characteristic_id.dart';
export 'src/models/ble_characteristic_value_event.dart';
export 'src/models/ble_gatt_descriptor.dart';
export 'src/models/ble_adapter_state.dart';
export 'src/models/ble_connection_state.dart';
export 'src/models/ble_gatt_service.dart';
export 'src/models/ble_scan_result.dart';
export 'src/models/connect_config.dart';
export 'src/models/scan_config.dart';

class FlutterBlueBackground {
  /// Current log verbosity for the Dart layer.
  static FbbLogLevel get logLevel => FbbLogger.level;

  /// Plain-text log stream (ANSI stripped). Useful for in-app debug consoles.
  static Stream<String> get logs => FbbLogger.logs;

  /// Sets plugin log verbosity on Dart and native.
  ///
  /// At [FbbLogLevel.verbose], method-channel calls and results are logged with
  /// colored output in the Dart console (flutter_blue_plus style).
  static Future<void> setLogLevel(FbbLogLevel level,
      {bool color = true}) async {
    FbbLogger.configure(level, color: color);
    await FlutterBlueBackgroundPlatform.instance.setLogLevel(level);
  }

  Future<String?> getPlatformVersion() {
    return FlutterBlueBackgroundPlatform.instance.getPlatformVersion();
  }

  /// Starts the native background (foreground) service so the app keeps
  /// running in the background. On Android this shows a persistent
  /// notification.
  ///
  /// Optionally customize the notification [notificationTitle] and
  /// [notificationContent].
  Future<bool> startService({
    String? notificationTitle,
    String? notificationContent,
  }) {
    return FlutterBlueBackgroundPlatform.instance.startService(
      notificationTitle: notificationTitle,
      notificationContent: notificationContent,
    );
  }

  /// Stops the native background service.
  Future<bool> stopService() {
    return FlutterBlueBackgroundPlatform.instance.stopService();
  }

  /// Returns whether the native background service is currently running.
  Future<bool> isServiceRunning() {
    return FlutterBlueBackgroundPlatform.instance.isServiceRunning();
  }

  /// Returns the current Bluetooth adapter (radio) state.
  Future<BleAdapterState> getAdapterState() {
    return FlutterBlueBackgroundPlatform.instance.getAdapterState();
  }

  /// A stream of Bluetooth adapter state changes.
  Stream<BleAdapterState> get adapterState =>
      FlutterBlueBackgroundPlatform.instance.adapterState;

  /// Starts a BLE scan using [config].
  ///
  /// Discovered devices are delivered on [scanResults]. Calling this while a
  /// scan is already running restarts the scan with the new [config].
  Future<bool> startScan([ScanConfig config = const ScanConfig()]) {
    return FlutterBlueBackgroundPlatform.instance.startScan(config);
  }

  /// Stops an in-progress BLE scan.
  Future<bool> stopScan() {
    return FlutterBlueBackgroundPlatform.instance.stopScan();
  }

  /// Whether a BLE scan is currently running.
  Future<bool> isScanning() {
    return FlutterBlueBackgroundPlatform.instance.isScanning();
  }

  /// A broadcast stream of BLE devices discovered during a scan.
  Stream<BleScanResult> get scanResults =>
      FlutterBlueBackgroundPlatform.instance.scanResults;

  /// Returns the cached snapshot of devices discovered during the current or
  /// most recent scan. On Android this includes devices found while the app UI
  /// was gone but the foreground service kept scanning.
  Future<List<BleScanResult>> getScanResults() {
    return FlutterBlueBackgroundPlatform.instance.getScanResults();
  }

  /// Clears the cached scan results.
  Future<bool> clearScanResults() {
    return FlutterBlueBackgroundPlatform.instance.clearScanResults();
  }

  /// Connects to [deviceId] (from [BleScanResult.deviceId]) using [config].
  ///
  /// Requires [startService] to be running first. When [ConnectConfig.autoConnect]
  /// is true, this returns once the native connect is initiated; listen to
  /// [connectionState] for the connected event.
  Future<bool> connect(
    String deviceId, [
    ConnectConfig config = const ConnectConfig(),
  ]) {
    return FlutterBlueBackgroundPlatform.instance.connect(deviceId, config);
  }

  /// Disconnects from [deviceId].
  Future<bool> disconnect(
    String deviceId, [
    DisconnectConfig config = const DisconnectConfig(),
  ]) {
    return FlutterBlueBackgroundPlatform.instance.disconnect(deviceId, config);
  }

  /// Cached connection state for [deviceId].
  Future<BleConnectionState> getConnectionState(String deviceId) {
    return FlutterBlueBackgroundPlatform.instance.getConnectionState(deviceId);
  }

  /// Device ids currently connected.
  Future<List<String>> getConnectedDevices() {
    return FlutterBlueBackgroundPlatform.instance.getConnectedDevices();
  }

  /// Broadcast stream of GATT connection state changes.
  Stream<BleConnectionEvent> get connectionState =>
      FlutterBlueBackgroundPlatform.instance.connectionState;

  /// Requests a larger ATT MTU on Android.
  ///
  /// On iOS the stack negotiates MTU automatically; this reads the current
  /// negotiated value via `maximumWriteValueLength` and emits it on
  /// [connectionState].
  Future<int> requestMtu(String deviceId, int mtu) {
    return FlutterBlueBackgroundPlatform.instance.requestMtu(deviceId, mtu);
  }

  /// Requests a connection priority update (Android only).
  Future<void> requestConnectionPriority(
    String deviceId,
    ConnectionPriority priority,
  ) {
    return FlutterBlueBackgroundPlatform.instance.requestConnectionPriority(
      deviceId,
      priority,
    );
  }

  /// Discovers GATT services on a connected device.
  Future<List<BleGattService>> discoverServices(
    String deviceId, {
    Duration timeout = const Duration(seconds: 15),
    bool subscribeToServicesChanged = true,
  }) {
    return FlutterBlueBackgroundPlatform.instance.discoverServices(
      deviceId,
      timeout: timeout,
      subscribeToServicesChanged: subscribeToServicesChanged,
    );
  }

  /// Reads a GATT characteristic value.
  ///
  /// Operations on the same [deviceId] are serialized (one at a time).
  /// Throws [FbbException] on failure.
  Future<Uint8List> readCharacteristic(
    String deviceId,
    BleCharacteristicId characteristic, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await BleOperationMutex.take(deviceId);
    try {
      return await FlutterBlueBackgroundPlatform.instance.readCharacteristic(
        deviceId,
        characteristic,
        timeout: timeout,
      );
    } finally {
      BleOperationMutex.give(deviceId);
    }
  }

  /// Writes [value] to a GATT characteristic.
  ///
  /// Operations on the same [deviceId] are serialized (one at a time).
  /// Throws [FbbException] on failure.
  Future<void> writeCharacteristic(
    String deviceId,
    BleCharacteristicId characteristic,
    List<int> value, {
    bool withoutResponse = false,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await BleOperationMutex.take(deviceId);
    try {
      await FlutterBlueBackgroundPlatform.instance.writeCharacteristic(
        deviceId,
        characteristic,
        value,
        withoutResponse: withoutResponse,
        timeout: timeout,
      );
    } finally {
      BleOperationMutex.give(deviceId);
    }
  }

  /// Enables or disables notifications/indications.
  ///
  /// Operations on the same [deviceId] are serialized (one at a time).
  /// Incoming values are delivered on [characteristicValues].
  /// Throws [FbbException] on failure.
  Future<void> setNotifyValue(
    String deviceId,
    BleCharacteristicId characteristic,
    bool enable, {
    bool forceIndications = false,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await BleOperationMutex.take(deviceId);
    try {
      await FlutterBlueBackgroundPlatform.instance.setNotifyValue(
        deviceId,
        characteristic,
        enable,
        forceIndications: forceIndications,
        timeout: timeout,
      );
    } finally {
      BleOperationMutex.give(deviceId);
    }
  }

  /// Stream of characteristic values from reads, write confirmations, and
  /// notifications for all connected devices.
  Stream<BleCharacteristicValueEvent> get characteristicValues =>
      FlutterBlueBackgroundPlatform.instance.characteristicValues;

  /// FBP-style filtered stream for a single characteristic.
  ///
  /// [sources] defaults to read, write, and notification events.
  Stream<BleCharacteristicValueEvent> characteristicValuesFor(
    String deviceId,
    BleCharacteristicId characteristic, {
    Set<BleCharacteristicValueSource> sources = const {
      BleCharacteristicValueSource.read,
      BleCharacteristicValueSource.write,
      BleCharacteristicValueSource.notification,
    },
  }) {
    return characteristicValues.where((event) {
      if (event.deviceId != deviceId) return false;
      if (event.serviceUuid != characteristic.serviceUuid) return false;
      if (event.characteristicUuid != characteristic.characteristicUuid) {
        return false;
      }
      if (event.instanceId != characteristic.instanceId) return false;
      return sources.contains(event.source);
    });
  }

  /// Notifications/indications only (matches FBP `onValueReceived`).
  Stream<BleCharacteristicValueEvent> onCharacteristicReceived(
    String deviceId,
    BleCharacteristicId characteristic,
  ) =>
      characteristicValuesFor(
        deviceId,
        characteristic,
        sources: const {BleCharacteristicValueSource.notification},
      );
}
