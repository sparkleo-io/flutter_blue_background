import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_background/flutter_blue_background.dart';
import 'package:flutter_blue_background/flutter_blue_background_platform_interface.dart';
import 'package:flutter_blue_background/flutter_blue_background_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:typed_data';

class MockFlutterBlueBackgroundPlatform
    with MockPlatformInterfaceMixin
    implements FlutterBlueBackgroundPlatform {
  bool running = false;

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> setLogLevel(FbbLogLevel level) => Future.value();

  @override
  Future<bool> startService({
    String? notificationTitle,
    String? notificationContent,
  }) {
    running = true;
    return Future.value(true);
  }

  @override
  Future<bool> stopService() {
    running = false;
    return Future.value(true);
  }

  @override
  Future<bool> isServiceRunning() => Future.value(running);

  @override
  Future<BleAdapterState> getAdapterState() => Future.value(BleAdapterState.on);

  @override
  Stream<BleAdapterState> get adapterState => Stream.value(BleAdapterState.on);

  bool scanning = false;

  @override
  Future<bool> startScan(ScanConfig config) {
    scanning = true;
    return Future.value(true);
  }

  @override
  Future<bool> stopScan() {
    scanning = false;
    return Future.value(true);
  }

  @override
  Future<bool> isScanning() => Future.value(scanning);

  @override
  Stream<BleScanResult> get scanResults => const Stream.empty();

  @override
  Future<List<BleScanResult>> getScanResults() => Future.value(const []);

  @override
  Future<bool> clearScanResults() => Future.value(true);

  final Map<String, BleConnectionState> connections = {};

  @override
  Future<bool> connect(String deviceId, ConnectConfig config) {
    connections[deviceId] = BleConnectionState.connected;
    return Future.value(true);
  }

  @override
  Future<bool> disconnect(String deviceId, DisconnectConfig config) {
    connections[deviceId] = BleConnectionState.disconnected;
    return Future.value(true);
  }

  @override
  Future<BleConnectionState> getConnectionState(String deviceId) =>
      Future.value(connections[deviceId] ?? BleConnectionState.disconnected);

  @override
  Future<List<String>> getConnectedDevices() => Future.value(
        connections.entries
            .where((e) => e.value == BleConnectionState.connected)
            .map((e) => e.key)
            .toList(),
      );

  @override
  Stream<BleConnectionEvent> get connectionState => const Stream.empty();

  @override
  Future<int> requestMtu(String deviceId, int mtu) => Future.value(mtu);

  @override
  Future<void> requestConnectionPriority(
    String deviceId,
    ConnectionPriority priority,
  ) =>
      Future.value();

  @override
  Future<List<BleGattService>> discoverServices(
    String deviceId, {
    Duration timeout = const Duration(seconds: 15),
    bool subscribeToServicesChanged = true,
  }) =>
      Future.value(const []);

  @override
  Future<Uint8List> readCharacteristic(
    String deviceId,
    BleCharacteristicId characteristic, {
    Duration timeout = const Duration(seconds: 15),
  }) =>
      Future.value(Uint8List.fromList([0x01]));

  @override
  Future<void> writeCharacteristic(
    String deviceId,
    BleCharacteristicId characteristic,
    List<int> value, {
    bool withoutResponse = false,
    Duration timeout = const Duration(seconds: 15),
  }) =>
      Future.value();

  @override
  Future<void> setNotifyValue(
    String deviceId,
    BleCharacteristicId characteristic,
    bool enable, {
    bool forceIndications = false,
    Duration timeout = const Duration(seconds: 15),
  }) =>
      Future.value();

  @override
  Stream<BleCharacteristicValueEvent> get characteristicValues =>
      const Stream.empty();
}

void main() {
  final FlutterBlueBackgroundPlatform initialPlatform =
      FlutterBlueBackgroundPlatform.instance;

  test('$MethodChannelFlutterBlueBackground is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterBlueBackground>());
  });

  test('getPlatformVersion', () async {
    FlutterBlueBackground flutterBlueBackgroundPlugin = FlutterBlueBackground();
    MockFlutterBlueBackgroundPlatform fakePlatform =
        MockFlutterBlueBackgroundPlatform();
    FlutterBlueBackgroundPlatform.instance = fakePlatform;

    expect(await flutterBlueBackgroundPlugin.getPlatformVersion(), '42');
  });

  test('start/stop service updates running state', () async {
    FlutterBlueBackground flutterBlueBackgroundPlugin = FlutterBlueBackground();
    MockFlutterBlueBackgroundPlatform fakePlatform =
        MockFlutterBlueBackgroundPlatform();
    FlutterBlueBackgroundPlatform.instance = fakePlatform;

    expect(await flutterBlueBackgroundPlugin.isServiceRunning(), false);

    expect(await flutterBlueBackgroundPlugin.startService(), true);
    expect(await flutterBlueBackgroundPlugin.isServiceRunning(), true);

    expect(await flutterBlueBackgroundPlugin.stopService(), true);
    expect(await flutterBlueBackgroundPlugin.isServiceRunning(), false);
  });
}
