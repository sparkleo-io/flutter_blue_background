import 'package:flutter_blue_background/flutter_blue_background.dart';

/// Builds Android foreground notification text from current BLE state.
class BleNotificationBuilder {
  const BleNotificationBuilder._();

  static String forAdapterState(
    BleAdapterState adapterState, {
    required String Function() buildWhenOn,
  }) {
    return switch (adapterState) {
      BleAdapterState.off => 'Bluetooth off',
      BleAdapterState.turningOff => 'Bluetooth turning off…',
      BleAdapterState.turningOn => 'Bluetooth turning on…',
      BleAdapterState.unauthorized => 'Bluetooth permission required',
      BleAdapterState.unsupported => 'Bluetooth not supported',
      BleAdapterState.on => buildWhenOn(),
      BleAdapterState.unknown => 'Bluetooth unavailable',
    };
  }

  static String adapterStatusMessage(
    BleAdapterState state, {
    required String currentStatus,
  }) {
    return switch (state) {
      BleAdapterState.off => 'Bluetooth off — scan and connections cleared',
      BleAdapterState.turningOff => 'Bluetooth turning off…',
      BleAdapterState.turningOn => 'Bluetooth turning on…',
      BleAdapterState.unauthorized => 'Bluetooth permission required',
      BleAdapterState.unsupported => 'Bluetooth LE not supported on this device',
      BleAdapterState.on => currentStatus,
      BleAdapterState.unknown => 'Bluetooth state unknown',
    };
  }

  static String whenAdapterOn({
    required bool isScanning,
    required Map<String, BleConnectionState> connectionStates,
    required Map<String, BleScanResult> devices,
  }) {
    final connecting = connectionStates.entries.where(
      (e) =>
          e.value == BleConnectionState.connecting ||
          e.value == BleConnectionState.disconnecting,
    );

    if (connecting.isNotEmpty) {
      final entry = connecting.first;
      final name = devices[entry.key]?.displayName ?? entry.key;
      return entry.value == BleConnectionState.connecting
          ? 'Connecting to $name…'
          : 'Disconnecting from $name…';
    }

    final connected = connectionStates.entries
        .where((e) => e.value == BleConnectionState.connected)
        .toList();

    if (connected.length == 1) {
      final id = connected.first.key;
      final name = devices[id]?.displayName ?? id;
      return 'Connected to $name';
    }
    if (connected.length > 1) {
      return 'Connected to ${connected.length} devices';
    }

    if (isScanning) return 'Scanning for devices';
    return 'Idle — use connect on a device';
  }
}
