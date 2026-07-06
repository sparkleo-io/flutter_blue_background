import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_blue_background_method_channel.dart';
import 'src/fbb_log_level.dart';
import 'src/models/ble_adapter_state.dart';
import 'src/models/ble_connection_state.dart';
import 'src/models/ble_characteristic_id.dart';
import 'src/models/ble_characteristic_value_event.dart';
import 'src/models/ble_gatt_service.dart';
import 'src/models/ble_scan_result.dart';
import 'src/models/connect_config.dart';
import 'src/models/scan_config.dart';

abstract class FlutterBlueBackgroundPlatform extends PlatformInterface {
  /// Constructs a FlutterBlueBackgroundPlatform.
  FlutterBlueBackgroundPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterBlueBackgroundPlatform _instance =
      MethodChannelFlutterBlueBackground();

  /// The default instance of [FlutterBlueBackgroundPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterBlueBackground].
  static FlutterBlueBackgroundPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterBlueBackgroundPlatform] when
  /// they register themselves.
  static set instance(FlutterBlueBackgroundPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Sets the plugin log verbosity on Dart and native layers.
  Future<void> setLogLevel(FbbLogLevel level) {
    throw UnimplementedError('setLogLevel() has not been implemented.');
  }

  /// Starts the native background (foreground) service.
  ///
  /// Optionally customizes the persistent notification shown while the service
  /// is running.
  Future<bool> startService({
    String? notificationTitle,
    String? notificationContent,
  }) {
    throw UnimplementedError('startService() has not been implemented.');
  }

  /// Stops the native background service.
  Future<bool> stopService() {
    throw UnimplementedError('stopService() has not been implemented.');
  }

  /// Whether the native background service is currently running.
  Future<bool> isServiceRunning() {
    throw UnimplementedError('isServiceRunning() has not been implemented.');
  }

  /// Returns the current Bluetooth adapter (radio) state.
  Future<BleAdapterState> getAdapterState() {
    throw UnimplementedError('getAdapterState() has not been implemented.');
  }

  /// A stream of Bluetooth adapter state changes.
  Stream<BleAdapterState> get adapterState {
    throw UnimplementedError('adapterState has not been implemented.');
  }

  /// Starts a BLE scan using [config].
  Future<bool> startScan(ScanConfig config) {
    throw UnimplementedError('startScan() has not been implemented.');
  }

  /// Stops an in-progress BLE scan.
  Future<bool> stopScan() {
    throw UnimplementedError('stopScan() has not been implemented.');
  }

  /// Whether a BLE scan is currently running.
  Future<bool> isScanning() {
    throw UnimplementedError('isScanning() has not been implemented.');
  }

  /// A broadcast stream of BLE devices discovered during a scan.
  Stream<BleScanResult> get scanResults {
    throw UnimplementedError('scanResults has not been implemented.');
  }

  /// Returns the cached snapshot of devices discovered during the current or
  /// most recent scan.
  ///
  /// Useful after returning to the foreground: on Android the scan keeps running
  /// inside the foreground service while the UI is gone, so this returns
  /// everything found in the meantime.
  Future<List<BleScanResult>> getScanResults() {
    throw UnimplementedError('getScanResults() has not been implemented.');
  }

  /// Clears the cached scan results.
  Future<bool> clearScanResults() {
    throw UnimplementedError('clearScanResults() has not been implemented.');
  }

  /// Establishes a GATT connection to [deviceId] using [config].
  ///
  /// Requires the background service to be running. Returns false when the
  /// service is stopped, Bluetooth is off, or permissions are missing.
  Future<bool> connect(String deviceId, ConnectConfig config) {
    throw UnimplementedError('connect() has not been implemented.');
  }

  /// Cancels the GATT connection to [deviceId].
  Future<bool> disconnect(String deviceId, DisconnectConfig config) {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  /// Returns the cached connection state for [deviceId].
  Future<BleConnectionState> getConnectionState(String deviceId) {
    throw UnimplementedError('getConnectionState() has not been implemented.');
  }

  /// Device ids currently in the [BleConnectionState.connected] state.
  Future<List<String>> getConnectedDevices() {
    throw UnimplementedError('getConnectedDevices() has not been implemented.');
  }

  /// Stream of connection state changes for all devices.
  Stream<BleConnectionEvent> get connectionState {
    throw UnimplementedError('connectionState has not been implemented.');
  }

  /// Requests a larger ATT MTU (Android only).
  Future<int> requestMtu(String deviceId, int mtu) {
    throw UnimplementedError('requestMtu() has not been implemented.');
  }

  /// Updates connection priority (Android only).
  Future<void> requestConnectionPriority(
    String deviceId,
    ConnectionPriority priority,
  ) {
    throw UnimplementedError(
        'requestConnectionPriority() has not been implemented.');
  }

  /// Discovers GATT services on a connected [deviceId].
  Future<List<BleGattService>> discoverServices(
    String deviceId, {
    Duration timeout = const Duration(seconds: 15),
    bool subscribeToServicesChanged = true,
  }) {
    throw UnimplementedError('discoverServices() has not been implemented.');
  }

  /// Reads a GATT characteristic value.
  ///
  /// Throws [FbbException] when the operation fails.
  Future<Uint8List> readCharacteristic(
    String deviceId,
    BleCharacteristicId characteristic, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    throw UnimplementedError('readCharacteristic() has not been implemented.');
  }

  /// Writes [value] to a GATT characteristic.
  ///
  /// Set [withoutResponse] for write-without-response characteristics.
  /// Throws [FbbException] when the operation fails.
  Future<void> writeCharacteristic(
    String deviceId,
    BleCharacteristicId characteristic,
    List<int> value, {
    bool withoutResponse = false,
    Duration timeout = const Duration(seconds: 15),
  }) {
    throw UnimplementedError('writeCharacteristic() has not been implemented.');
  }

  /// Enables or disables notifications/indications on a characteristic.
  ///
  /// Incoming values are delivered on [characteristicValues].
  /// Throws [FbbException] when the operation fails.
  Future<void> setNotifyValue(
    String deviceId,
    BleCharacteristicId characteristic,
    bool enable, {
    bool forceIndications = false,
    Duration timeout = const Duration(seconds: 15),
  }) {
    throw UnimplementedError('setNotifyValue() has not been implemented.');
  }

  /// Stream of characteristic values from reads, writes, and notifications.
  Stream<BleCharacteristicValueEvent> get characteristicValues {
    throw UnimplementedError('characteristicValues has not been implemented.');
  }
}
