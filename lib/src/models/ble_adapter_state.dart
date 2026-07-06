/// Cross-platform Bluetooth adapter (radio) state.
///
/// Values are aligned with [flutter_blue_plus] `BluetoothAdapterState` and map
/// from native platform APIs on both Android and iOS.
enum BleAdapterState {
  unknown,
  unsupported,
  unauthorized,
  off,
  turningOn,
  on,
  turningOff;

  /// Whether the adapter is powered on and ready for BLE operations.
  bool get isOn => this == BleAdapterState.on;

  /// Whether scanning can be started immediately.
  bool get canScan => this == BleAdapterState.on;

  /// Whether a new GATT connection can be initiated.
  bool get canConnect => this == BleAdapterState.on;

  /// Adapter is transitioning between powered-off and powered-on.
  bool get isTransitioning =>
      this == BleAdapterState.turningOn || this == BleAdapterState.turningOff;

  /// Whether active scan/connection state must be torn down.
  ///
  /// When true, native code stops scans, closes GATT links, and emits
  /// `disconnected` events. Does not apply to [turningOn] — that is a
  /// recovery state only.
  bool get requiresBleTeardown =>
      this == BleAdapterState.off ||
      this == BleAdapterState.turningOff ||
      this == BleAdapterState.unsupported ||
      this == BleAdapterState.unauthorized;

  /// Parses the string emitted by the native platform.
  factory BleAdapterState.fromNative(String? value) {
    if (value == null || value.isEmpty) return BleAdapterState.unknown;
    for (final state in BleAdapterState.values) {
      if (state.name == value) return state;
    }
    return BleAdapterState.unknown;
  }
}
