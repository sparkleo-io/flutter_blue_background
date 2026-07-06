/// GATT link state for a remote BLE device.
///
/// Aligned with [flutter_blue_plus] `BluetoothConnectionState`.
enum BleConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting;

  factory BleConnectionState.fromNative(String? value) {
    if (value == null || value.isEmpty) return BleConnectionState.disconnected;
    for (final state in BleConnectionState.values) {
      if (state.name == value) return state;
    }
    return BleConnectionState.disconnected;
  }
}

/// A connection state change delivered on [FlutterBlueBackground.connectionState].
class BleConnectionEvent {
  const BleConnectionEvent({
    required this.deviceId,
    required this.state,
    this.mtu,
    this.errorMessage,
    this.errorCode,
  });

  /// Stable device identifier (MAC on Android, UUID on iOS).
  final String deviceId;

  /// Current link state after this event.
  final BleConnectionState state;

  /// Negotiated ATT MTU when known (emitted on connect / mtu change).
  final int? mtu;

  /// Human-readable disconnect or connection failure reason, if any.
  final String? errorMessage;

  /// Platform-specific error/status code when available.
  final int? errorCode;

  factory BleConnectionEvent.fromMap(Map<dynamic, dynamic> map) {
    return BleConnectionEvent(
      deviceId: map['deviceId'] as String,
      state: BleConnectionState.fromNative(map['state'] as String?),
      mtu: map['mtu'] as int?,
      errorMessage: map['errorMessage'] as String?,
      errorCode: map['errorCode'] as int?,
    );
  }
}
