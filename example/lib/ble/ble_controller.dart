import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_blue_background/flutter_blue_background.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ble_gatt_exchange_entry.dart';
import 'ble_log_entry.dart';
import 'ble_notification_builder.dart';
import '../widgets/gatt_service_tree.dart';

/// Shared BLE state for the example app: service, scan, and GATT connections.
class BleController extends GetxController {
  BleController({FlutterBlueBackground? plugin})
      : _plugin = plugin ?? FlutterBlueBackground();

  final FlutterBlueBackground _plugin;

  static const _maxLogEntries = 40;
  static const _maxExchangeEntries = 50;
  static const _macCommandText = 'measure';
  static const _macCommandLineEnding = '\n';
  static const _macCommandInterval = Duration(seconds: 1);
  static const _nordicUartRxUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

  final isRunning = false.obs;
  final isScanning = false.obs;
  final adapterState = BleAdapterState.unknown.obs;
  final polledAdapterState = Rxn<BleAdapterState>();
  final status = 'Idle'.obs;
  final platformVersion = RxnString();
  final gattStatusMessage = ''.obs;

  final RxMap<String, BleScanResult> devices = <String, BleScanResult>{}.obs;
  final RxMap<String, BleConnectionState> connectionStates =
      <String, BleConnectionState>{}.obs;
  final RxMap<String, int> deviceMtu = <String, int>{}.obs;
  final RxMap<String, List<BleGattService>> discoveredServices =
      <String, List<BleGattService>>{}.obs;
  final RxMap<String, bool> isDiscoveringServices = <String, bool>{}.obs;
  final RxMap<String, String> characteristicValueHex = <String, String>{}.obs;
  final RxMap<String, String> characteristicValueText = <String, String>{}.obs;
  final RxSet<String> notifyingCharacteristics = <String>{}.obs;
  final RxList<GattExchangeEntry> gattExchangeLog = <GattExchangeEntry>[].obs;

  final RxList<String> queriedConnectedDeviceIds = <String>[].obs;
  final RxMap<String, BleConnectionState> queriedConnectionStates =
      <String, BleConnectionState>{}.obs;

  final queryStatusMessage = ''.obs;
  final isQueryingConnections = false.obs;

  final RxList<AdapterStateLogEntry> adapterStateLog =
      <AdapterStateLogEntry>[].obs;
  final RxList<ConnectionLogEntry> connectionEventLog =
      <ConnectionLogEntry>[].obs;

  final RxMap<String, bool> macCommandSending = <String, bool>{}.obs;

  StreamSubscription<BleScanResult>? _scanSub;
  StreamSubscription<BleAdapterState>? _adapterSub;
  StreamSubscription<BleConnectionEvent>? _connectionSub;
  StreamSubscription<BleCharacteristicValueEvent>? _characteristicValuesSub;

  final Map<String, Timer> _macCommandTimers = {};

  static const skipUnnamedDevices = true;

  String? _lastNotificationContent;
  bool _notificationUpdateInFlight = false;

  List<BleScanResult> get sortedDevices {
    final list = devices.values.toList();
    list.sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
    return list;
  }

  BleScanResult? deviceFor(String deviceId) => devices[deviceId];

  String displayNameFor(String deviceId) =>
      devices[deviceId]?.displayName ?? deviceId;

  @override
  void onInit() {
    super.onInit();
    _restoreState();
    _scanSub = _plugin.scanResults.listen(_addScanResult);
    _adapterSub = _plugin.adapterState.listen(_onAdapterStreamEvent);
    _connectionSub = _plugin.connectionState.listen(_onConnectionEvent);
    _characteristicValuesSub =
        _plugin.characteristicValues.listen(_onCharacteristicValue);
    _logAdapterState(adapterState.value, source: 'initial');
    unawaited(fetchPlatformVersion());
  }

  @override
  void onClose() {
    _stopAllMacCommandSending();
    _scanSub?.cancel();
    _adapterSub?.cancel();
    _connectionSub?.cancel();
    _characteristicValuesSub?.cancel();
    super.onClose();
  }

  void _logAdapterState(BleAdapterState state, {required String source}) {
    adapterStateLog.insert(
      0,
      AdapterStateLogEntry(
        timestamp: DateTime.now(),
        state: state,
        source: source,
      ),
    );
    if (adapterStateLog.length > _maxLogEntries) {
      adapterStateLog.removeRange(_maxLogEntries, adapterStateLog.length);
    }
    adapterStateLog.refresh();
  }

  void _logConnectionEvent(BleConnectionEvent event) {
    connectionEventLog.insert(
      0,
      ConnectionLogEntry(timestamp: DateTime.now(), event: event),
    );
    if (connectionEventLog.length > _maxLogEntries) {
      connectionEventLog.removeRange(_maxLogEntries, connectionEventLog.length);
    }
    connectionEventLog.refresh();
  }

  Future<void> _onAdapterStreamEvent(BleAdapterState state) async {
    if (state == adapterState.value) return;

    adapterState.value = state;
    _logAdapterState(state, source: 'stream');

    if (state.requiresBleTeardown) {
      await _handleAdapterUnavailable(state);
      return;
    }

    if (state == BleAdapterState.turningOn) {
      status.value = BleNotificationBuilder.adapterStatusMessage(
        state,
        currentStatus: status.value,
      );
      await _updateNotification();
      return;
    }

    if (state.isOn) {
      await _syncBleStateFromNative();
    }
  }

  void _onConnectionEvent(BleConnectionEvent event) {
    _logConnectionEvent(event);
    _setConnectionState(event.deviceId, event.state);

    if (event.mtu != null) {
      deviceMtu[event.deviceId] = event.mtu!;
    }

    if (event.state == BleConnectionState.connected) {
      status.value = 'Connected to ${event.deviceId} (mtu ${event.mtu ?? '?'})';
      unawaited(discoverServicesFor(event.deviceId));
    } else if (event.state == BleConnectionState.disconnected) {
      stopMacCommandSending(event.deviceId);
      discoveredServices.remove(event.deviceId);
      isDiscoveringServices.remove(event.deviceId);
      if (event.errorMessage != null) {
        status.value = 'Disconnected: ${event.errorMessage}';
      }
    }

    _updateNotification();
  }

  void _setConnectionState(String deviceId, BleConnectionState state) {
    connectionStates[deviceId] = state;
    connectionStates.refresh();
  }

  void _clearAllConnectionStates() {
    connectionStates.clear();
    connectionStates.refresh();
    deviceMtu.clear();
    discoveredServices.clear();
    isDiscoveringServices.clear();
  }

  Future<void> _handleAdapterUnavailable(BleAdapterState state) async {
    isScanning.value = false;
    _clearAllConnectionStates();
    queriedConnectedDeviceIds.clear();
    queriedConnectionStates.clear();
    status.value = BleNotificationBuilder.adapterStatusMessage(
      state,
      currentStatus: status.value,
    );
    await _updateNotification();
  }

  Future<void> _syncBleStateFromNative() async {
    isScanning.value = await _plugin.isScanning();
    _clearAllConnectionStates();

    final connected = await _plugin.getConnectedDevices();
    for (final id in connected) {
      _setConnectionState(id, BleConnectionState.connected);
    }

    if (isScanning.value) {
      status.value = 'Scanning…';
    } else if (connected.isNotEmpty) {
      status.value = 'Connected to ${connected.length} device(s)';
    } else if (isRunning.value) {
      status.value = 'Bluetooth on — ready';
    }

    await _updateNotification();
  }

  String _buildNotificationContent() {
    if (!adapterState.value.isOn) {
      return BleNotificationBuilder.forAdapterState(
        adapterState.value,
        buildWhenOn: () => '',
      );
    }

    return BleNotificationBuilder.whenAdapterOn(
      isScanning: isScanning.value,
      connectionStates: Map<String, BleConnectionState>.from(connectionStates),
      devices: Map<String, BleScanResult>.from(devices),
    );
  }

  Future<void> _updateNotification() async {
    if (!isRunning.value || _notificationUpdateInFlight) return;

    final content = _buildNotificationContent();
    if (content == _lastNotificationContent) return;

    _notificationUpdateInFlight = true;
    try {
      await _plugin.startService(
        notificationTitle: 'Flutter Blue Background',
        notificationContent: content,
      );
      _lastNotificationContent = content;
    } finally {
      _notificationUpdateInFlight = false;
    }
  }

  void _addScanResult(BleScanResult result) {
    if (skipUnnamedDevices && !result.hasAdvertisedName) return;
    devices[result.deviceId] = result;
  }

  Future<void> _restoreState() async {
    isRunning.value = await _plugin.isServiceRunning();
    isScanning.value = await _plugin.isScanning();
    adapterState.value = await _plugin.getAdapterState();
    _logAdapterState(adapterState.value, source: 'poll');

    final cached = await _plugin.getScanResults();
    for (final result in cached) {
      _addScanResult(result);
    }

    if (adapterState.value.isOn) {
      await _syncBleStateFromNative();
    } else {
      isScanning.value = false;
      _clearAllConnectionStates();
      status.value = BleNotificationBuilder.adapterStatusMessage(
        adapterState.value,
        currentStatus: status.value,
      );
    }

    if (isRunning.value && adapterState.value.isOn && !isScanning.value) {
      status.value = 'Service running — Bluetooth on';
    } else if (!isRunning.value) {
      status.value = 'Idle';
    }

    await _updateNotification();
  }

  Future<void> _refreshRunningState() async {
    isRunning.value = await _plugin.isServiceRunning();
  }

  Future<bool> ensurePermissions() async {
    if (!Platform.isAndroid) {
      // iOS prompts for Bluetooth via NSBluetoothAlwaysUsageDescription when
      // CoreBluetooth is used. No push/local notification permission is needed.
      return true;
    }

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.notification,
    ].request();

    final scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final connectOk = statuses[Permission.bluetoothConnect]?.isGranted ?? false;

    // Android 12+ needs both Nearby Devices permissions for scan + adapter access.
    return scanOk && connectOk;
  }

  void clearLogs() {
    adapterStateLog.clear();
    connectionEventLog.clear();
    adapterStateLog.refresh();
    connectionEventLog.refresh();
    _logAdapterState(adapterState.value, source: 'stream');
  }

  // — Platform / adapter —

  Future<void> fetchPlatformVersion() async {
    platformVersion.value = await _plugin.getPlatformVersion();
  }

  Future<void> fetchAdapterState() async {
    final state = await _plugin.getAdapterState();
    polledAdapterState.value = state;
    _logAdapterState(state, source: 'poll');
    queryStatusMessage.value = 'getAdapterState(): ${state.name}';
  }

  // — Service —

  Future<void> startService() async {
    status.value = 'Requesting permissions...';
    if (!await ensurePermissions()) {
      status.value = 'Bluetooth permission denied';
      return;
    }

    // Adapter stream only updates on radio changes — re-poll after grant.
    adapterState.value = await _plugin.getAdapterState();
    _logAdapterState(adapterState.value, source: 'poll');

    if (adapterState.value == BleAdapterState.unauthorized) {
      status.value = 'Bluetooth permission denied — grant Nearby devices '
          'in system settings';
      return;
    }

    final started = await _plugin.startService(
      notificationTitle: 'Flutter Blue Background',
      notificationContent: _buildNotificationContent(),
    );
    status.value = started ? 'Service started' : 'Failed to start';
    await _refreshRunningState();
  }

  Future<void> stopService() async {
    final stopped = await _plugin.stopService();
    isScanning.value = await _plugin.isScanning();
    _lastNotificationContent = null;
    status.value = stopped ? 'Service stopped' : 'Failed to stop';
    await _refreshRunningState();
  }

  Future<void> refreshServiceFlags() async {
    isRunning.value = await _plugin.isServiceRunning();
    isScanning.value = await _plugin.isScanning();
    status.value = 'Refreshed — service ${isRunning.value}, '
        'scanning ${isScanning.value}';
  }

  // — Scan —

  Future<void> startScan() async {
    if (!isRunning.value) {
      status.value = 'Start the service first';
      return;
    }

    if (!await ensurePermissions()) {
      status.value = 'Bluetooth permission denied';
      return;
    }

    adapterState.value = await _plugin.getAdapterState();
    _logAdapterState(adapterState.value, source: 'poll');

    if (!adapterState.value.canScan) {
      status.value = 'Bluetooth is ${adapterState.value.name}';
      return;
    }

    devices.clear();

    const config = ScanConfig(
      serviceUuids: [],
      skipUnnamedDevices: skipUnnamedDevices,
      rssiThreshold: -180,
      android: AndroidScanSettings(scanMode: AndroidScanMode.lowLatency),
      ios: IosScanOptions(allowDuplicates: true),
    );

    final started = await _plugin.startScan(config);
    isScanning.value = started;
    status.value =
        started ? 'Scanning...' : 'Failed to start scan (is Bluetooth on?)';
    await _updateNotification();
  }

  Future<void> stopScan() async {
    await _plugin.stopScan();
    isScanning.value = false;
    status.value = 'Scan stopped';
    await _updateNotification();
  }

  Future<void> refreshCachedScanResults() async {
    final cached = await _plugin.getScanResults();
    for (final result in cached) {
      _addScanResult(result);
    }
    status.value = 'getScanResults(): ${cached.length} device(s) in cache';
  }

  Future<void> clearCachedScanResults() async {
    await _plugin.clearScanResults();
    devices.clear();
    status.value = 'clearScanResults(): cache cleared';
  }

  Future<void> connectTo(BleScanResult device) async {
    if (!isRunning.value) {
      status.value = 'Start the service first';
      return;
    }

    if (!adapterState.value.canConnect) {
      status.value = BleNotificationBuilder.adapterStatusMessage(
        adapterState.value,
        currentStatus: status.value,
      );
      return;
    }

    status.value = 'Connecting to ${device.displayName}...';
    _setConnectionState(device.deviceId, BleConnectionState.connecting);
    await _updateNotification();

    const config = ConnectConfig(
      timeout: Duration(seconds: 15),
      discoverServicesOnConnect: true,
      android: AndroidConnectOptions(
        mtu: 512,
        connectionPriority: ConnectionPriority.high,
      ),
    );

    final started = await _plugin.connect(device.deviceId, config);
    if (!started) {
      status.value = 'Failed to start connection';
      _setConnectionState(device.deviceId, BleConnectionState.disconnected);
      await _updateNotification();
    }
  }

  Future<void> connectToDeviceId(String deviceId) async {
    final device = devices[deviceId] ?? BleScanResult(deviceId: deviceId);
    await connectTo(device);
  }

  Future<void> disconnectFrom(String deviceId) async {
    stopMacCommandSending(deviceId);
    _setConnectionState(deviceId, BleConnectionState.disconnecting);
    await _updateNotification();
    await _plugin.disconnect(deviceId);
    _setConnectionState(deviceId, BleConnectionState.disconnected);
    discoveredServices.remove(deviceId);
    _clearCharacteristicStateForDevice(deviceId);
    status.value = 'Disconnected';
    await _updateNotification();
  }

  // — GATT —

  Future<void> discoverServicesFor(String deviceId) async {
    if (connectionStates[deviceId] != BleConnectionState.connected) {
      gattStatusMessage.value = 'Device must be connected to discover services';
      return;
    }

    isDiscoveringServices[deviceId] = true;
    isDiscoveringServices.refresh();
    gattStatusMessage.value = 'discoverServices($deviceId)…';

    try {
      final services = await _plugin.discoverServices(deviceId);
      discoveredServices[deviceId] = services;
      discoveredServices.refresh();
      gattStatusMessage.value = services.isEmpty
          ? 'discoverServices(): no services found'
          : 'discoverServices(): ${services.length} service(s), '
              '${services.fold<int>(0, (n, s) => n + s.characteristics.length)} '
              'characteristic(s)';
    } catch (e) {
      gattStatusMessage.value = 'discoverServices() failed: $e';
    } finally {
      isDiscoveringServices[deviceId] = false;
      isDiscoveringServices.refresh();
    }
  }

  Future<void> requestMtuFor(String deviceId, {int mtu = 512}) async {
    gattStatusMessage.value = 'requestMtu($deviceId, $mtu)…';
    try {
      final negotiated = await _plugin.requestMtu(deviceId, mtu);
      deviceMtu[deviceId] = negotiated;
      deviceMtu.refresh();
      gattStatusMessage.value = 'requestMtu(): negotiated $negotiated'
          '${negotiated < mtu ? ' (iOS negotiates MTU automatically)' : ''}';
    } catch (e) {
      gattStatusMessage.value = 'requestMtu() failed: $e';
    }
  }

  Future<void> requestConnectionPriorityFor(
    String deviceId,
    ConnectionPriority priority,
  ) async {
    gattStatusMessage.value =
        'requestConnectionPriority($deviceId, ${priority.name})…';
    try {
      await _plugin.requestConnectionPriority(deviceId, priority);
      gattStatusMessage.value =
          'requestConnectionPriority(): ${priority.name} applied';
    } catch (e) {
      gattStatusMessage.value = 'requestConnectionPriority() failed: $e';
    }
  }

  String characteristicKey(
    String deviceId,
    String serviceUuid,
    BleGattCharacteristic characteristic,
  ) =>
      '$deviceId|${GattServiceTree.characteristicKey(serviceUuid, characteristic)}';

  String _eventCharacteristicKey(BleCharacteristicValueEvent event) =>
      '${event.deviceId}|${GattServiceTree.characteristicKey(
        event.serviceUuid,
        BleGattCharacteristic(
          uuid: event.characteristicUuid,
          instanceId: event.instanceId,
        ),
      )}';

  void _onCharacteristicValue(BleCharacteristicValueEvent event) {
    if (!event.success) {
      gattStatusMessage.value =
          'GATT ${event.source.name} failed on ${event.characteristicUuid}: '
          '${event.errorMessage ?? event.errorCode ?? "unknown"}';
      return;
    }

    final key = _eventCharacteristicKey(event);
    _storeCharacteristicValue(key, event.value);

    final text = bytesToString(event.value);
    final hex = _formatBytes(event.value);
    final source = event.source.name;

    switch (event.source) {
      case BleCharacteristicValueSource.notification:
      case BleCharacteristicValueSource.read:
        _logExchange(
          deviceId: event.deviceId,
          direction: 'received',
          serviceUuid: event.serviceUuid,
          characteristicUuid: event.characteristicUuid,
          text: text,
          hex: hex,
          source: source,
        );
        gattStatusMessage.value =
            'received ($source) ${event.characteristicUuid}: $text';
      case BleCharacteristicValueSource.write:
        gattStatusMessage.value =
            'sent ($source) ${event.characteristicUuid}: $text';
    }
  }

  void _storeCharacteristicValue(String key, List<int> bytes) {
    characteristicValueHex[key] = _formatBytes(bytes);
    characteristicValueText[key] = bytesToString(bytes);
    characteristicValueHex.refresh();
    characteristicValueText.refresh();
  }

  void _logExchange({
    required String deviceId,
    required String direction,
    required String serviceUuid,
    required String characteristicUuid,
    required String text,
    required String hex,
    required String source,
  }) {
    gattExchangeLog.insert(
      0,
      GattExchangeEntry(
        timestamp: DateTime.now(),
        deviceId: deviceId,
        direction: direction,
        serviceUuid: serviceUuid,
        characteristicUuid: characteristicUuid,
        text: text,
        hex: hex,
        source: source,
      ),
    );
    if (gattExchangeLog.length > _maxExchangeEntries) {
      gattExchangeLog.removeRange(_maxExchangeEntries, gattExchangeLog.length);
    }
    gattExchangeLog.refresh();
  }

  List<GattExchangeEntry> exchangeLogFor(String deviceId) =>
      gattExchangeLog.where((e) => e.deviceId == deviceId).toList();

  void _clearCharacteristicStateForDevice(String deviceId) {
    stopMacCommandSending(deviceId);
    final prefix = '$deviceId|';
    characteristicValueHex.removeWhere((key, _) => key.startsWith(prefix));
    characteristicValueText.removeWhere((key, _) => key.startsWith(prefix));
    notifyingCharacteristics.removeWhere((key) => key.startsWith(prefix));
    characteristicValueHex.refresh();
    characteristicValueText.refresh();
    notifyingCharacteristics.refresh();
    gattExchangeLog.removeWhere((e) => e.deviceId == deviceId);
    gattExchangeLog.refresh();
  }

  String _formatBytes(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  /// UTF-8 text to send over GATT (e.g. "mac" → 6d 61 63).
  List<int> stringToBytes(String text) => utf8.encode(text);

  /// Device bytes back to a display string.
  String bytesToString(List<int> bytes) {
    if (bytes.isEmpty) return '';
    return utf8.decode(bytes, allowMalformed: true);
  }

  BleCharacteristicId _characteristicId(
    String serviceUuid,
    BleGattCharacteristic characteristic,
  ) =>
      BleCharacteristicId(
        serviceUuid: serviceUuid,
        characteristicUuid: characteristic.uuid,
        instanceId: characteristic.instanceId,
      );

  Future<void> readCharacteristicFor(
    String deviceId,
    String serviceUuid,
    BleGattCharacteristic characteristic,
  ) async {
    final id = _characteristicId(serviceUuid, characteristic);
    gattStatusMessage.value = 'readCharacteristic(${characteristic.uuid})…';
    try {
      final value = await _plugin.readCharacteristic(deviceId, id);
      final key = characteristicKey(deviceId, serviceUuid, characteristic);
      _storeCharacteristicValue(key, value);
      _logExchange(
        deviceId: deviceId,
        direction: 'received',
        serviceUuid: serviceUuid,
        characteristicUuid: characteristic.uuid,
        text: bytesToString(value),
        hex: _formatBytes(value),
        source: 'read',
      );
      gattStatusMessage.value = 'readCharacteristic(): ${bytesToString(value)}';
    } on FbbException catch (e) {
      gattStatusMessage.value = 'readCharacteristic() failed: $e';
    } catch (e) {
      gattStatusMessage.value = 'readCharacteristic() failed: $e';
    }
  }

  Future<void> writeStringFor(
    String deviceId,
    String serviceUuid,
    BleGattCharacteristic characteristic,
    String text, {
    bool? withoutResponse,
    String lineEnding = '',
  }) async {
    final payload = '$text$lineEnding';
    final bytes = stringToBytes(payload);
    final id = _characteristicId(serviceUuid, characteristic);
    final hasWriteNoResp =
        characteristic.properties.contains('writeWithoutResponse');
    final useWithoutResponse = withoutResponse ?? hasWriteNoResp;
    gattStatusMessage.value = 'writeCharacteristic(${characteristic.uuid})…';
    try {
      await _plugin.writeCharacteristic(
        deviceId,
        id,
        bytes,
        withoutResponse: useWithoutResponse,
      );
      final key = characteristicKey(deviceId, serviceUuid, characteristic);
      _storeCharacteristicValue(key, bytes);
      _logExchange(
        deviceId: deviceId,
        direction: 'sent',
        serviceUuid: serviceUuid,
        characteristicUuid: characteristic.uuid,
        text: payload,
        hex: _formatBytes(bytes),
        source: 'write',
      );
      gattStatusMessage.value = 'writeCharacteristic(): sent "$payload"';
    } on FbbException catch (e) {
      gattStatusMessage.value = 'writeCharacteristic() failed: $e';
    } catch (e) {
      gattStatusMessage.value = 'writeCharacteristic() failed: $e';
    }
  }

  Future<void> writeCharacteristicFor(
    String deviceId,
    String serviceUuid,
    BleGattCharacteristic characteristic,
    List<int> value, {
    bool withoutResponse = false,
  }) async {
    await writeStringFor(
      deviceId,
      serviceUuid,
      characteristic,
      bytesToString(value),
    );
  }

  Future<void> toggleNotifyFor(
    String deviceId,
    String serviceUuid,
    BleGattCharacteristic characteristic,
  ) async {
    final key = characteristicKey(deviceId, serviceUuid, characteristic);
    final enable = !notifyingCharacteristics.contains(key);
    final id = _characteristicId(serviceUuid, characteristic);
    gattStatusMessage.value =
        'setNotifyValue(${characteristic.uuid}, enable: $enable)…';
    try {
      await _plugin.setNotifyValue(deviceId, id, enable);
      if (enable) {
        notifyingCharacteristics.add(key);
      } else {
        notifyingCharacteristics.remove(key);
      }
      notifyingCharacteristics.refresh();
      gattStatusMessage.value =
          'setNotifyValue(): ${enable ? 'enabled' : 'disabled'}';
    } on FbbException catch (e) {
      gattStatusMessage.value = 'setNotifyValue() failed: $e';
    } catch (e) {
      gattStatusMessage.value = 'setNotifyValue() failed: $e';
    }
  }

  // — Periodic mac command —

  bool isMacCommandSending(String deviceId) =>
      macCommandSending[deviceId] ?? false;

  bool hasWritableCharacteristicForMacCommand(String deviceId) =>
      _writableTargetForMacCommand(deviceId) != null;

  void toggleMacCommandSending(String deviceId) {
    if (isMacCommandSending(deviceId)) {
      stopMacCommandSending(deviceId);
    } else {
      unawaited(startMacCommandSending(deviceId));
    }
  }

  Future<void> startMacCommandSending(String deviceId) async {
    if (isMacCommandSending(deviceId)) return;

    if (connectionStates[deviceId] != BleConnectionState.connected) {
      gattStatusMessage.value = 'Device must be connected to send mac command';
      return;
    }

    final target = _writableTargetForMacCommand(deviceId);
    if (target == null) {
      gattStatusMessage.value =
          'No writable characteristic — run discoverServices() first';
      return;
    }

    macCommandSending[deviceId] = true;
    macCommandSending.refresh();
    gattStatusMessage.value =
        'Sending "$_macCommandText\\n" every ${_macCommandInterval.inSeconds}s';

    await _sendMacCommand(
      deviceId,
      target.serviceUuid,
      target.characteristic,
    );

    _macCommandTimers[deviceId] = Timer.periodic(_macCommandInterval, (_) {
      unawaited(_sendMacCommand(
        deviceId,
        target.serviceUuid,
        target.characteristic,
      ));
    });
  }

  void stopMacCommandSending(String deviceId) {
    _macCommandTimers.remove(deviceId)?.cancel();
    if (macCommandSending.remove(deviceId) != null) {
      macCommandSending.refresh();
      gattStatusMessage.value = 'Stopped periodic mac command';
    }
  }

  void _stopAllMacCommandSending() {
    for (final deviceId in _macCommandTimers.keys.toList()) {
      stopMacCommandSending(deviceId);
    }
  }

  ({String serviceUuid, BleGattCharacteristic characteristic})?
      _writableTargetForMacCommand(String deviceId) {
    final services = discoveredServices[deviceId];
    if (services == null || services.isEmpty) return null;

    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (_uuidMatches(characteristic.uuid, _nordicUartRxUuid) &&
            characteristic.canWrite) {
          return (serviceUuid: service.uuid, characteristic: characteristic);
        }
      }
    }

    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (characteristic.canWrite) {
          return (serviceUuid: service.uuid, characteristic: characteristic);
        }
      }
    }
    return null;
  }

  bool _uuidMatches(String a, String b) {
    final normalize = (String uuid) => uuid.toLowerCase().replaceAll('-', '');
    return normalize(a) == normalize(b);
  }

  Future<void> _sendMacCommand(
    String deviceId,
    String serviceUuid,
    BleGattCharacteristic characteristic,
  ) async {
    if (!isMacCommandSending(deviceId)) return;
    if (connectionStates[deviceId] != BleConnectionState.connected) {
      stopMacCommandSending(deviceId);
      return;
    }

    await writeStringFor(
      deviceId,
      serviceUuid,
      characteristic,
      _macCommandText,
      lineEnding: _macCommandLineEnding,
    );
  }

  // — Connection queries —

  Future<void> fetchConnectedDevices() async {
    isQueryingConnections.value = true;
    queryStatusMessage.value = 'Calling getConnectedDevices()…';

    try {
      final ids = await _plugin.getConnectedDevices();
      queriedConnectedDeviceIds.assignAll(ids);
      queryStatusMessage.value = ids.isEmpty
          ? 'getConnectedDevices(): no devices connected'
          : 'getConnectedDevices(): ${ids.length} device(s)';
    } catch (e) {
      queryStatusMessage.value = 'getConnectedDevices() failed: $e';
      queriedConnectedDeviceIds.clear();
    } finally {
      isQueryingConnections.value = false;
    }
  }

  Future<void> fetchConnectionState(String deviceId) async {
    if (deviceId.isEmpty) {
      queryStatusMessage.value = 'Enter or pick a device id first';
      return;
    }

    isQueryingConnections.value = true;
    queryStatusMessage.value = 'Calling getConnectionState($deviceId)…';

    try {
      final state = await _plugin.getConnectionState(deviceId);
      queriedConnectionStates[deviceId] = state;
      queriedConnectionStates.refresh();
      queryStatusMessage.value = 'getConnectionState($deviceId): ${state.name}';
    } catch (e) {
      queryStatusMessage.value = 'getConnectionState() failed: $e';
    } finally {
      isQueryingConnections.value = false;
    }
  }

  Future<void> fetchAllKnownConnectionStates() async {
    final ids = <String>{
      ...devices.keys,
      ...connectionStates.keys,
      ...queriedConnectedDeviceIds,
    };

    if (ids.isEmpty) {
      queryStatusMessage.value = 'No devices to query — scan or connect first';
      return;
    }

    isQueryingConnections.value = true;
    queryStatusMessage.value = 'Querying ${ids.length} device(s)…';

    try {
      for (final id in ids) {
        queriedConnectionStates[id] = await _plugin.getConnectionState(id);
      }
      queriedConnectionStates.refresh();
      queryStatusMessage.value =
          'Queried getConnectionState() for ${ids.length} device(s)';
    } catch (e) {
      queryStatusMessage.value = 'Batch getConnectionState() failed: $e';
    } finally {
      isQueryingConnections.value = false;
    }
  }
}
