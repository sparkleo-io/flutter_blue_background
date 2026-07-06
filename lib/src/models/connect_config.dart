/// Android GATT transport for [AndroidConnectOptions.transport].
enum AndroidGattTransport {
  /// Let the stack choose (not recommended for LE peripherals).
  auto(0),

  /// Classic Bluetooth BR/EDR.
  bredr(1),

  /// Bluetooth Low Energy (recommended default).
  le(2);

  const AndroidGattTransport(this.nativeValue);
  final int nativeValue;
}

/// Android preferred PHY for the initial connection.
enum AndroidGattPhy {
  le1m(1),
  le2m(2),
  leCoded(3);

  const AndroidGattPhy(this.nativeValue);
  final int nativeValue;
}

/// Android connection priority (applied after connect via GATT).
enum ConnectionPriority {
  balanced(0),
  high(1),
  lowPower(2);

  const ConnectionPriority(this.nativeValue);
  final int nativeValue;
}

/// Android-only connection tuning. Ignored on iOS.
class AndroidConnectOptions {
  const AndroidConnectOptions({
    this.transport = AndroidGattTransport.le,
    this.phy = AndroidGattPhy.le1m,
    this.mtu = 512,
    this.connectionPriority = ConnectionPriority.balanced,
    this.disconnectDelayMillis = 2000,
  });

  /// Preferred GATT transport. Defaults to LE.
  final AndroidGattTransport transport;

  /// Preferred PHY. Ignored when [ConnectConfig.autoConnect] is true.
  final AndroidGattPhy phy;

  /// MTU to request after connect. Must be null when [ConnectConfig.autoConnect]
  /// is true — call [FlutterBlueBackground.requestMtu] manually instead.
  final int? mtu;

  /// Connection interval / latency preference applied after connect.
  final ConnectionPriority connectionPriority;

  /// Minimum gap between connect and disconnect to avoid Android GATT races.
  final int disconnectDelayMillis;

  Map<String, dynamic> toMap() => {
        'transport': transport.nativeValue,
        'phy': phy.nativeValue,
        if (mtu != null) 'mtu': mtu,
        'connectionPriority': connectionPriority.nativeValue,
        'disconnectDelayMillis': disconnectDelayMillis,
      };
}

/// iOS-only connection options. Ignored on Android.
class IosConnectOptions {
  const IosConnectOptions({
    this.enableAutoReconnect = false,
    this.notifyOnConnection = false,
    this.notifyOnDisconnection = false,
    this.notifyOnNotification = false,
  });

  /// `CBConnectPeripheralOptionEnableAutoReconnect` (iOS 17+).
  final bool enableAutoReconnect;

  /// System alert when connected while suspended (apps without bluetooth-central).
  final bool notifyOnConnection;

  /// System alert on disconnect while suspended.
  final bool notifyOnDisconnection;

  /// System alert on notification while suspended.
  final bool notifyOnNotification;

  Map<String, dynamic> toMap() => {
        'enableAutoReconnect': enableAutoReconnect,
        'notifyOnConnection': notifyOnConnection,
        'notifyOnDisconnection': notifyOnDisconnection,
        'notifyOnNotification': notifyOnNotification,
      };
}

/// Configuration for establishing a GATT connection.
class ConnectConfig {
  const ConnectConfig({
    this.timeout = const Duration(seconds: 35),
    this.autoConnect = false,
    this.discoverServicesOnConnect = true,
    this.serviceUuids = const [],
    this.subscribeToServicesChanged = true,
    this.android = const AndroidConnectOptions(),
    this.ios = const IosConnectOptions(),
  });

  /// How long to wait for a direct connection before failing.
  ///
  /// Ignored when [autoConnect] is true (the OS manages reconnection).
  final Duration timeout;

  /// When true, the native connect call returns immediately and the OS
  /// reconnects whenever the device is available. Listen to
  /// [FlutterBlueBackground.connectionState] for the connected state.
  ///
  /// Incompatible with [AndroidConnectOptions.mtu] at connect time.
  final bool autoConnect;

  /// Whether to run service discovery automatically after connecting.
  final bool discoverServicesOnConnect;

  /// Optional service UUID filter passed to discovery.
  final List<String> serviceUuids;

  /// Subscribe to the GAP Services Changed characteristic (0x2A05).
  final bool subscribeToServicesChanged;

  final AndroidConnectOptions android;
  final IosConnectOptions ios;

  Map<String, dynamic> toMap() {
    final androidMap = android.toMap();
    if (autoConnect) {
      androidMap.remove('mtu');
    }
    return {
      'timeoutMillis': timeout.inMilliseconds,
      'autoConnect': autoConnect,
      'discoverServicesOnConnect': discoverServicesOnConnect,
      'serviceUuids': serviceUuids,
      'subscribeToServicesChanged': subscribeToServicesChanged,
      'android': androidMap,
      'ios': ios.toMap(),
    };
  }
}

/// Configuration for cancelling a GATT connection.
class DisconnectConfig {
  const DisconnectConfig({
    this.timeout = const Duration(seconds: 35),
    this.androidDelayMillis = 2000,
  });

  /// How long to wait for the disconnected state.
  final Duration timeout;

  /// Android-only minimum gap after a recent connect (GATT race workaround).
  final int androidDelayMillis;

  Map<String, dynamic> toMap() => {
        'timeoutMillis': timeout.inMilliseconds,
        'androidDelayMillis': androidDelayMillis,
      };
}
