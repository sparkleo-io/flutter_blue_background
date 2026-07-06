# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.0.2

### Added

- Native BLE stack on Android and iOS (`BleScanner`, `BleConnector`) running inside a background service instead of Dart-only BLE via `flutter_background_service`.
- Instance-based `FlutterBlueBackground` API with method + event channels.
- Background service lifecycle: `startService`, `stopService`, `isServiceRunning` with customizable Android notification title/content.
- BLE scanning: `startScan`, `stopScan`, `isScanning`, `getScanResults`, `clearScanResults`.
- `ScanConfig` with cross-platform filters (`serviceUuids`, `nameFilter`, `skipUnnamedDevices`, `rssiThreshold`, `timeout`) and platform tuning (`AndroidScanSettings`, `IosScanOptions`).
- Connection management: `connect`, `disconnect`, `getConnectionState`, `getConnectedDevices` with `ConnectConfig` / `DisconnectConfig`.
- GATT operations: `discoverServices`, `readCharacteristic`, `writeCharacteristic`, `setNotifyValue`, `requestMtu`, `requestConnectionPriority`.
- Real-time streams: `adapterState`, `scanResults`, `connectionState`, `characteristicValues`, plus `characteristicValuesFor` and `onCharacteristicReceived` helpers.
- Cross-platform models aligned with flutter_blue_plus semantics: `BleAdapterState`, `BleConnectionState`, `BleScanResult`, `BleGattService`, `BleCharacteristicValueEvent`, etc.
- Per-device GATT operation serialization via `BleOperationMutex`.
- Structured logging: `FbbLogLevel`, `setLogLevel`, and `FlutterBlueBackground.logs` stream with native log forwarding.
- `FbbException` for typed GATT / connection errors.
- Android boot receiver to restart the service after reboot when it was running.
- Android scan-result caching and state restoration across app lifecycle.
- iOS `bluetooth-central` background mode support with native `BackgroundService`.
- Full example app (scan, connect, GATT read/write/notify, adapter/connection query screens).
- Unit tests for the Dart API and method channel.

### Changed

- **Breaking:** Removed the legacy static API (`FlutterBlueBackground.initialize`, `BleConfig`, `BleCallbacks`, `GenericBleService`, battery-monitoring helpers, and `flutter_background_service` integration).
- **Breaking:** Replaced callback-based device handling with streams and explicit scan/connect/GATT calls.
- README rewritten with installation, platform setup, permissions, API reference, configuration, and background-behavior notes.
- Android foreground service type set to `connectedDevice`; Gradle and manifest updated for modern Flutter plugin structure.
- iOS plugin migrated to Swift Package layout with dedicated scanner/connector modules.

### Fixed

- Reliable background scanning and connecting when the Flutter isolate is suspended.
- Bluetooth permission handling for Android 12+ and iOS (`NSBluetoothAlwaysUsageDescription`).
- iOS CoreBluetooth connect options only pass `true` NSNumber flags (avoids invalid-parameter connect failures).
- Adapter state teardown when Bluetooth is turned off or unauthorized.
- Android GATT write-without-response and notify/indicate selection aligned with iOS / flutter_blue_plus behavior.


## 0.0.1

### Added

- Initial release of `flutter_blue_background`.
- Generic, configurable BLE background service built on `flutter_background_service`.
- `BleConfig` for service/characteristic UUIDs, device name/ID, timeouts, MTU, and auto-reconnect.
- Battery level and health monitoring with configurable thresholds.
- Callback system for device events, data, and errors.
- Cross-platform Android/iOS background service entry points.
- Legacy initialization helpers for existing integrations.
