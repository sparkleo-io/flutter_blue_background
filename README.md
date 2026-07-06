# Flutter Blue Background

A Flutter plugin for **Bluetooth Low Energy (BLE)** that keeps scanning, connecting, and GATT operations alive while your app is in the background — on **Android** and **iOS**.

`flutter_blue_background` is designed for apps that need reliable peripheral communication when the UI is not visible: wearables, sensors, medical devices, asset trackers, and similar use cases. The API is intentionally aligned with [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) naming and semantics where practical, so migration is straightforward.

---

## Table of contents

- [Features](#features)
- [How it works](#how-it-works)
- [Installation](#installation)
- [Platform setup](#platform-setup)
- [Permissions](#permissions)
- [Quick start](#quick-start)
- [Typical workflow](#typical-workflow)
- [API reference](#api-reference)
- [Configuration](#configuration)
- [Data models](#data-models)
- [Streams](#streams)
- [Background behavior](#background-behavior)
- [Logging](#logging)
- [Error handling](#error-handling)
- [Example app](#example-app)
- [Limitations & best practices](#limitations--best-practices)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- **Background BLE** — Android foreground service (`connectedDevice` type) and iOS `bluetooth-central` background mode keep the stack active when the app is backgrounded.
- **Scan** — Filter by service UUID, name, RSSI; platform-specific tuning for Android and iOS.
- **Connect / disconnect** — Direct or auto-connect; configurable timeouts and platform options.
- **GATT** — Service discovery, read, write, notifications/indications.
- **Streams** — Real-time adapter state, scan results, connection state, and characteristic values.
- **Cached scan results** — On Android, devices found while the UI was away are available via `getScanResults()`.
- **Serialized GATT ops** — Per-device mutex prevents overlapping read/write/notify calls.
- **Boot restart (Android)** — Service can restart after reboot if it was running before.
- **Logging** — Dart and native log levels with an in-app log stream.
- **Cross-platform models** — `BleAdapterState`, `BleConnectionState`, and scan result fields aligned with flutter_blue_plus.

---

## How it works

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter (Dart)                          │
│  FlutterBlueBackground                                      │
│    • startService / stopService                             │
│    • startScan / connect / GATT ops                         │
│    • Streams: adapterState, scanResults, connectionState,   │
│               characteristicValues                          │
└──────────────────────────┬──────────────────────────────────┘
                           │ Method + Event channels
         ┌─────────────────┴─────────────────┐
         ▼                                   ▼
┌─────────────────────┐           ┌─────────────────────┐
│      Android        │           │        iOS          │
│ Foreground service  │           │ BackgroundService   │
│  + BleScanner       │           │  + BleScanner       │
│  + BleConnector     │           │  + BleConnector     │
│  + BootReceiver     │           │  (bluetooth-central)│
└─────────────────────┘           └─────────────────────┘
```

**Android** runs BLE inside a long-lived foreground service with a persistent notification, wake lock, and periodic keep-alive. Scan and connect intents are handled natively so work continues when the Flutter isolate is suspended.

**iOS** relies on the host app declaring `bluetooth-central` in `UIBackgroundModes`. The plugin holds `UIApplication` background tasks during foreground/background transitions. There is no Android-style notification on iOS.

**Important:** Scanning and connecting require `startService()` to be running first. The plugin does not implicitly start the service.

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_blue_background: ^0.0.2
```

Import:

```dart
import 'package:flutter_blue_background/flutter_blue_background.dart';
```

Create an instance (methods are instance-based, not static):

```dart
final ble = FlutterBlueBackground();
```

---

## Platform setup

### Android

The plugin merges these into your app manifest automatically:

- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_CONNECTED_DEVICE`
- `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN` (with `neverForLocation`)
- `POST_NOTIFICATIONS`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`
- Legacy `BLUETOOTH` / `BLUETOOTH_ADMIN` and `ACCESS_FINE_LOCATION` (API ≤ 30)

Your **app** manifest should declare runtime permissions you intend to request (see [Permissions](#permissions)). The example app includes:

```xml
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission
    android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation"
    tools:targetApi="s"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

No extra service declaration is needed in the app — the plugin registers `FlutterBlueBackgroundService` with `foregroundServiceType="connectedDevice"`.

### iOS

1. In Xcode, enable **Background Modes** → **Uses Bluetooth LE accessories**.

2. Add to `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to communicate with nearby devices in the background.</string>
```

`NSBluetoothPeripheralUsageDescription` is included for older iOS versions.

---

## Permissions

| Platform | What you need |
|----------|----------------|
| **Android 12+** | `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` at runtime. `POST_NOTIFICATIONS` for the foreground service notification. |
| **Android ≤ 11** | Location permission may be required for scanning (plugin declares `ACCESS_FINE_LOCATION` for API ≤ 30). |
| **iOS** | System prompts via `NSBluetoothAlwaysUsageDescription` when CoreBluetooth is first used. No separate notification permission for BLE. |

The [example app](example/) uses [`permission_handler`](https://pub.dev/packages/permission_handler) to request Android permissions before `startService()`.

---

## Quick start

```dart
import 'package:flutter_blue_background/flutter_blue_background.dart';

final ble = FlutterBlueBackground();

Future<void> runBle() async {
  // 1. Optional: enable verbose logging
  await FlutterBlueBackground.setLogLevel(FbbLogLevel.debug);

  // 2. Start the background service (required before scan/connect)
  await ble.startService(
    notificationTitle: 'My BLE App',
    notificationContent: 'Connected to device',
  );

  // 3. Listen for discoveries
  ble.scanResults.listen((result) {
    print('Found: ${result.displayName} (${result.rssi} dBm)');
  });

  // 4. Start scanning
  await ble.startScan(const ScanConfig(
    serviceUuids: ['6e400001-b5a3-f393-e0a9-e50e24dcca9e'],
    skipUnnamedDevices: true,
  ));

  // 5. Connect when you have a deviceId from a scan result
  const deviceId = 'AA:BB:CC:DD:EE:FF'; // MAC on Android; UUID on iOS

  ble.connectionState.listen((event) async {
    if (event.state == BleConnectionState.connected) {
      final services = await ble.discoverServices(deviceId);
      print('Discovered ${services.length} services');
    }
  });

  await ble.connect(deviceId);

  // 6. Read / write / subscribe
  const charId = BleCharacteristicId(
    serviceUuid: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
    characteristicUuid: '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
  );

  ble.onCharacteristicReceived(deviceId, charId).listen((event) {
    print('Notification: ${event.value}');
  });

  await ble.setNotifyValue(deviceId, charId, true);
  await ble.writeCharacteristic(
    deviceId,
    BleCharacteristicId(
      serviceUuid: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
      characteristicUuid: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
    ),
    [0x01, 0x02],
  );
}
```

---

## Typical workflow

1. **Request permissions** (Android) — before any BLE work.
2. **`startService()`** — must succeed before scan or connect.
3. **Subscribe to streams** — `adapterState`, `scanResults`, `connectionState`, `characteristicValues`.
4. **`startScan(ScanConfig)`** — discover peripherals; use `deviceId` from `BleScanResult`.
5. **`connect(deviceId, ConnectConfig)`** — wait for `BleConnectionState.connected` on `connectionState`.
6. **`discoverServices(deviceId)`** — inspect GATT tree; read/write/notify as needed.
7. **`stopScan()`** / **`disconnect()`** / **`stopService()`** when finished.

On app resume, call `isServiceRunning()`, `isScanning()`, `getScanResults()`, and `getConnectedDevices()` to reconcile UI state with native reality.

---

## API reference

### `FlutterBlueBackground`

| Method / property | Description |
|-------------------|-------------|
| `setLogLevel(level, {color})` | Static. Sets Dart + native log verbosity. |
| `logLevel` | Static. Current `FbbLogLevel`. |
| `logs` | Static. `Stream<String>` of plain-text log lines. |
| `getPlatformVersion()` | Native OS version string. |
| `startService({notificationTitle, notificationContent})` | Start background service. Returns `false` on failure. |
| `stopService()` | Stop service; tears down scan and connections on iOS. |
| `isServiceRunning()` | Whether the service is active. |
| `getAdapterState()` | One-shot adapter (radio) state. |
| `adapterState` | `Stream<BleAdapterState>`. |
| `startScan([ScanConfig])` | Start BLE scan. Restarts if already scanning. Requires service. |
| `stopScan()` | Stop scan. |
| `isScanning()` | Whether a scan is in progress. |
| `scanResults` | `Stream<BleScanResult>`. |
| `getScanResults()` | Cached results from current/recent scan. |
| `clearScanResults()` | Clear cache. |
| `connect(deviceId, [ConnectConfig])` | Connect to peripheral. Requires service. |
| `disconnect(deviceId, [DisconnectConfig])` | Disconnect. |
| `getConnectionState(deviceId)` | Cached state for one device. |
| `getConnectedDevices()` | List of connected `deviceId`s. |
| `connectionState` | `Stream<BleConnectionEvent>`. |
| `requestMtu(deviceId, mtu)` | Request ATT MTU (Android). iOS reports negotiated MTU via events. |
| `requestConnectionPriority(deviceId, priority)` | Android only. |
| `discoverServices(deviceId, {timeout, subscribeToServicesChanged})` | GATT service discovery. |
| `readCharacteristic(deviceId, characteristic, {timeout})` | Read value. Serialized per device. |
| `writeCharacteristic(deviceId, characteristic, value, {withoutResponse, timeout})` | Write value. |
| `setNotifyValue(deviceId, characteristic, enable, {forceIndications, timeout})` | Enable/disable CCCD. |
| `characteristicValues` | All read/write/notification events. |
| `characteristicValuesFor(deviceId, characteristic, {sources})` | Filtered stream. |
| `onCharacteristicReceived(deviceId, characteristic)` | Notifications only (FBP-style). |

---

## Configuration

### `ScanConfig`

Cross-platform fields:

| Field | Description |
|-------|-------------|
| `serviceUuids` | Native filter. **Required for iOS background scan delivery.** |
| `nameFilter` | Case-insensitive substring on advertised name (client-side). |
| `skipUnnamedDevices` | Drop devices with no local name in the advertisement. |
| `rssiThreshold` | Drop weak signals (dBm, client-side). |
| `reportDelay` | Android batch interval. |
| `timeout` | Auto-stop after duration; `null` = until `stopScan()`. |
| `android` | `AndroidScanSettings` — scan mode, callback type, PHY, etc. |
| `ios` | `IosScanOptions` — `allowDuplicates`, `solicitedServiceUuids`. |

### `ConnectConfig`

| Field | Description |
|-------|-------------|
| `timeout` | Direct connect timeout (ignored when `autoConnect` is true). |
| `autoConnect` | OS-managed reconnection; listen on `connectionState`. |
| `discoverServicesOnConnect` | Auto discovery after connect (default `true`). |
| `serviceUuids` | Optional discovery filter. |
| `subscribeToServicesChanged` | Subscribe to GAP Services Changed (0x2A05). |
| `android` | `AndroidConnectOptions` — transport, PHY, MTU, priority. |
| `ios` | `IosConnectOptions` — auto-reconnect (iOS 17+), suspend alerts. |

When `autoConnect` is `true`, do not set `android.mtu` at connect time — call `requestMtu()` after connected.

### `DisconnectConfig`

| Field | Description |
|-------|-------------|
| `timeout` | Wait for disconnected state. |
| `androidDelayMillis` | Minimum gap after recent connect (GATT race workaround). |

---

## Data models

### `BleScanResult`

| Field | Notes |
|-------|-------|
| `deviceId` | **Android:** MAC address. **iOS:** `CBPeripheral` UUID (not MAC). |
| `advName` | Local name from advertisement only. |
| `platformName` | Bonded/cached name. |
| `displayName` | `advName` → `platformName` → `deviceId`. |
| `rssi`, `txPowerLevel`, `connectable` | Signal and connectability. |
| `manufacturerData`, `serviceUuids`, `serviceData` | Advertisement payload. |

### `BleConnectionEvent`

`deviceId`, `state` (`BleConnectionState`), optional `mtu`, `errorMessage`, `errorCode`.

### `BleGattService` / `BleGattCharacteristic`

Service and characteristic UUIDs, properties (`read`, `write`, `notify`, …), descriptors.

### `BleCharacteristicId`

`serviceUuid`, `characteristicUuid`, `instanceId` (Android duplicate characteristics).

### `BleCharacteristicValueEvent`

`value`, `source` (`read` | `write` | `notification`), `success`, error fields.

### `BleAdapterState`

`unknown`, `unsupported`, `unauthorized`, `off`, `turningOn`, `on`, `turningOff`.

Use `isOn`, `canScan`, `canConnect`, and `requiresBleTeardown` helpers.

---

## Streams

| Stream | Emits |
|--------|-------|
| `adapterState` | Radio on/off/unauthorized transitions. |
| `scanResults` | Each matching advertisement (may be filtered client-side). |
| `connectionState` | Connect, disconnect, MTU updates. |
| `characteristicValues` | Reads, write confirmations, notifications. |

Subscribe **before** starting scan/connect to avoid missing early events. Streams are broadcast; multiple listeners are supported.

---

## Background behavior

### Android

- Foreground notification is shown while the service runs. Customize text via `startService(notificationTitle:, notificationContent:)`.
- Scan continues in the service when the app is backgrounded. Use `getScanResults()` when returning to the foreground.
- `BootReceiver` restarts the service after reboot **only if** it was running when the device shut down.
- Adapter off/unauthorized triggers native teardown: scans stop, GATT links close, `disconnected` events fire.

### iOS

- Background scan delivery requires peripherals to advertise a UUID listed in `ScanConfig.serviceUuids`.
- In background, iOS delivers **one** scan event per device (duplicates suppressed) unless in foreground with `allowDuplicates: true`.
- `deviceId` is an opaque UUID — store it to reconnect to the same peripheral later.
- Long-lived BLE in background depends on `bluetooth-central`; the plugin's `BackgroundService` adds short `beginBackgroundTask` extensions during transitions.

---

## Logging

```dart
await FlutterBlueBackground.setLogLevel(FbbLogLevel.verbose, color: true);

FlutterBlueBackground.logs.listen(print); // in-app debug console
```

Levels: `none`, `error`, `warning`, `info`, `debug`, `verbose` (matches flutter_blue_plus ordering).

At `verbose`, method-channel calls and results are logged in the Dart console.

---

## Error handling

GATT operations throw `FbbException` with `method`, `message`, and optional `errorCode`:

```dart
try {
  await ble.readCharacteristic(deviceId, charId);
} on FbbException catch (e) {
  print('${e.method}: ${e.message}');
}
```

`connect()` and `startScan()` return `false` on failure (service stopped, Bluetooth off, permissions missing) rather than throwing.

Connection failures include `errorMessage` / `errorCode` on `BleConnectionEvent`.

---

## Example app

The [`example/`](example/) project is a full demo with four tabs:

| Tab | Demonstrates |
|-----|----------------|
| **Service** | Start/stop service, notification updates |
| **Adapter** | Adapter state stream and polling |
| **Scan** | Scan config, live results, cached results, connect |
| **Connection** | Query connection state, GATT tree, read/write/notify |

Run from the example directory:

```bash
cd example
flutter run
```

Key reference: [`example/lib/ble/ble_controller.dart`](example/lib/ble/ble_controller.dart).

---

## Limitations & best practices

1. **Always start the service first** — `startScan` and `connect` return `false` otherwise.
2. **Filter service UUIDs on iOS** — especially for background scanning.
3. **Use `deviceId` from scan results** — do not assume MAC addresses on iOS.
4. **One GATT operation at a time per device** — enforced by the plugin; queue higher-level logic if needed.
5. **Handle `requiresBleTeardown`** — when the adapter turns off, clear local connection UI state.
6. **Battery** — background BLE is power-intensive; use scan timeouts, RSSI thresholds, and stop scan when connected.
7. **Not a drop-in replacement for flutter_blue_plus in foreground-only apps** — this plugin optimizes for background lifecycle and native service ownership.

---

## Contributing

Contributions are welcome. Please open an issue or pull request on [GitHub](https://github.com/sparkleo-io/flutter_blue_background).

---

## License

MIT — see [LICENSE](LICENSE).
