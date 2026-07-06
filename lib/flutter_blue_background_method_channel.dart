import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_blue_background_platform_interface.dart';
import 'src/fbb_log_level.dart';
import 'src/fbb_logger.dart';
import 'src/gatt_operation_result.dart';
import 'src/models/ble_adapter_state.dart';
import 'src/models/ble_connection_state.dart';
import 'src/models/ble_characteristic_id.dart';
import 'src/models/ble_characteristic_value_event.dart';
import 'src/models/ble_gatt_service.dart';
import 'src/models/ble_scan_result.dart';
import 'src/models/connect_config.dart';
import 'src/models/scan_config.dart';

/// An implementation of [FlutterBlueBackgroundPlatform] that uses method channels.
class MethodChannelFlutterBlueBackground extends FlutterBlueBackgroundPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_blue_background');

  /// The event channel that streams BLE scan results from the native platform.
  @visibleForTesting
  final scanResultsChannel =
      const EventChannel('flutter_blue_background/scan_results');

  /// The event channel that streams Bluetooth adapter state changes.
  @visibleForTesting
  final adapterStateChannel =
      const EventChannel('flutter_blue_background/adapter_state');

  /// The event channel that streams GATT connection state changes.
  @visibleForTesting
  final connectionStateChannel =
      const EventChannel('flutter_blue_background/connection_state');

  /// The event channel that streams GATT characteristic value events.
  @visibleForTesting
  final characteristicValuesChannel =
      const EventChannel('flutter_blue_background/characteristic_values');

  Stream<BleScanResult>? _scanResults;
  Stream<BleAdapterState>? _adapterState;
  Stream<BleConnectionEvent>? _connectionState;
  Stream<BleCharacteristicValueEvent>? _characteristicValues;

  Future<T?> _invokeMethod<T>(String method, [dynamic arguments]) async {
    FbbLogger.logMethodArgs(method, arguments);
    final result = await methodChannel.invokeMethod<T>(method, arguments);
    FbbLogger.logMethodResult(method, result);
    return result;
  }

  @override
  Future<void> setLogLevel(FbbLogLevel level) async {
    await _invokeMethod<void>('setLogLevel', level.index);
  }

  @override
  Future<String?> getPlatformVersion() async {
    return _invokeMethod<String>('getPlatformVersion');
  }

  @override
  Future<bool> startService({
    String? notificationTitle,
    String? notificationContent,
  }) async {
    final started = await _invokeMethod<bool>('startService', {
      'notificationTitle': notificationTitle,
      'notificationContent': notificationContent,
    });
    return started ?? false;
  }

  @override
  Future<bool> stopService() async {
    final stopped = await _invokeMethod<bool>('stopService');
    return stopped ?? false;
  }

  @override
  Future<bool> isServiceRunning() async {
    final running = await _invokeMethod<bool>('isServiceRunning');
    return running ?? false;
  }

  @override
  Future<BleAdapterState> getAdapterState() async {
    final state = await _invokeMethod<String>('getAdapterState');
    return BleAdapterState.fromNative(state);
  }

  @override
  Stream<BleAdapterState> get adapterState {
    _adapterState ??= adapterStateChannel
        .receiveBroadcastStream()
        .map((event) => BleAdapterState.fromNative(event as String?));
    return _adapterState!;
  }

  @override
  Future<bool> startScan(ScanConfig config) async {
    final started = await _invokeMethod<bool>(
      'startScan',
      config.toMap(),
    );
    return started ?? false;
  }

  @override
  Future<bool> stopScan() async {
    final stopped = await _invokeMethod<bool>('stopScan');
    return stopped ?? false;
  }

  @override
  Future<bool> isScanning() async {
    final scanning = await _invokeMethod<bool>('isScanning');
    return scanning ?? false;
  }

  @override
  Stream<BleScanResult> get scanResults {
    _scanResults ??= scanResultsChannel
        .receiveBroadcastStream()
        .map((event) => BleScanResult.fromMap(event as Map<dynamic, dynamic>));
    return _scanResults!;
  }

  @override
  Future<List<BleScanResult>> getScanResults() async {
    final results = await _invokeMethod<List<dynamic>>(
      'getScanResults',
    );
    if (results == null) return const [];
    return results
        .map((e) => BleScanResult.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  @override
  Future<bool> clearScanResults() async {
    final cleared = await _invokeMethod<bool>('clearScanResults');
    return cleared ?? false;
  }

  @override
  Future<bool> connect(String deviceId, ConnectConfig config) async {
    final connected = await _invokeMethod<bool>('connect', {
      'deviceId': deviceId,
      'config': config.toMap(),
    });
    return connected ?? false;
  }

  @override
  Future<bool> disconnect(String deviceId, DisconnectConfig config) async {
    final disconnected = await _invokeMethod<bool>('disconnect', {
      'deviceId': deviceId,
      'config': config.toMap(),
    });
    return disconnected ?? false;
  }

  @override
  Future<BleConnectionState> getConnectionState(String deviceId) async {
    final state = await _invokeMethod<String>(
      'getConnectionState',
      {'deviceId': deviceId},
    );
    return BleConnectionState.fromNative(state);
  }

  @override
  Future<List<String>> getConnectedDevices() async {
    final devices = await _invokeMethod<List<dynamic>>(
      'getConnectedDevices',
    );
    if (devices == null) return const [];
    return devices.map((e) => e.toString()).toList();
  }

  @override
  Stream<BleConnectionEvent> get connectionState {
    _connectionState ??= connectionStateChannel.receiveBroadcastStream().map(
        (event) => BleConnectionEvent.fromMap(event as Map<dynamic, dynamic>));
    return _connectionState!;
  }

  @override
  Future<int> requestMtu(String deviceId, int mtu) async {
    final result = await _invokeMethod<int>('requestMtu', {
      'deviceId': deviceId,
      'mtu': mtu,
    });
    return result ?? 23;
  }

  @override
  Future<void> requestConnectionPriority(
    String deviceId,
    ConnectionPriority priority,
  ) async {
    await _invokeMethod<void>('requestConnectionPriority', {
      'deviceId': deviceId,
      'priority': priority.nativeValue,
    });
  }

  @override
  Future<List<BleGattService>> discoverServices(
    String deviceId, {
    Duration timeout = const Duration(seconds: 15),
    bool subscribeToServicesChanged = true,
  }) async {
    final services = await _invokeMethod<List<dynamic>>(
      'discoverServices',
      {
        'deviceId': deviceId,
        'timeoutMillis': timeout.inMilliseconds,
        'subscribeToServicesChanged': subscribeToServicesChanged,
      },
    );
    if (services == null) return const [];
    return services
        .map((e) => BleGattService.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  Map<String, dynamic> _characteristicArgs(
    String deviceId,
    BleCharacteristicId characteristic,
    Duration timeout,
  ) {
    return {
      'deviceId': deviceId,
      ...characteristic.toMap(),
      'timeoutMillis': timeout.inMilliseconds,
    };
  }

  @override
  Future<Uint8List> readCharacteristic(
    String deviceId,
    BleCharacteristicId characteristic, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final result = await _invokeMethod<Map<dynamic, dynamic>>(
      'readCharacteristic',
      _characteristicArgs(deviceId, characteristic, timeout),
    );
    return GattOperationResult.parseRead('readCharacteristic', result);
  }

  @override
  Future<void> writeCharacteristic(
    String deviceId,
    BleCharacteristicId characteristic,
    List<int> value, {
    bool withoutResponse = false,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final result = await _invokeMethod<Map<dynamic, dynamic>>(
      'writeCharacteristic',
      {
        ..._characteristicArgs(deviceId, characteristic, timeout),
        'value': Uint8List.fromList(value),
        'withoutResponse': withoutResponse,
      },
    );
    GattOperationResult.parseVoid('writeCharacteristic', result);
  }

  @override
  Future<void> setNotifyValue(
    String deviceId,
    BleCharacteristicId characteristic,
    bool enable, {
    bool forceIndications = false,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final result = await _invokeMethod<Map<dynamic, dynamic>>(
      'setNotifyValue',
      {
        ..._characteristicArgs(deviceId, characteristic, timeout),
        'enable': enable,
        'forceIndications': forceIndications,
      },
    );
    GattOperationResult.parseSetNotify('setNotifyValue', result);
  }

  @override
  Stream<BleCharacteristicValueEvent> get characteristicValues {
    _characteristicValues ??= characteristicValuesChannel
        .receiveBroadcastStream()
        .map((event) => BleCharacteristicValueEvent.fromMap(
            event as Map<dynamic, dynamic>));
    return _characteristicValues!;
  }
}
