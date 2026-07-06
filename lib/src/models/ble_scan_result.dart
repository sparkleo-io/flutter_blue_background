import 'dart:typed_data';

/// A single BLE advertisement discovered during a scan.
///
/// This is emitted on the [FlutterBlueBackground.scanResults] stream. Some
/// fields are platform-dependent (see field docs) because Android and iOS
/// expose different information in their discovery callbacks.
///
/// Naming follows:
/// - [advName]: local name from the advertisement packet only.
/// - [platformName]: cached/platform name (bonded device, prior connection).
/// - [displayName]: [advName] if present, else [platformName], else [deviceId].
class BleScanResult {
  BleScanResult({
    required this.deviceId,
    this.advName = '',
    this.platformName = '',
    this.name,
    this.rssi,
    this.txPowerLevel,
    this.connectable,
    this.manufacturerData,
    this.serviceUuids = const [],
    this.serviceData = const {},
    this.timestampMillis,
  });

  /// Stable identifier for the device.
  ///
  /// - Android: the hardware MAC address (e.g. `AA:BB:CC:DD:EE:FF`).
  /// - iOS: the `CBPeripheral.identifier` UUID string. iOS never exposes the
  ///   MAC address; this id is what you pass back to connect/reconnect.
  final String deviceId;

  /// Local name from the advertisement packet (`advName`).
  ///
  /// Empty when the device did not include a name in its advertisement.
  final String advName;

  /// Platform/cached device name (`platformName`).
  ///
  /// May be populated even when [advName] is empty (e.g. a previously bonded
  /// device on Android).
  final String platformName;

  /// Best available name: [advName], then [platformName], then null.
  ///
  /// Prefer [displayName] for UI labels.
  final String? name;

  /// Received signal strength indicator, in dBm. Closer to 0 is stronger.
  final int? rssi;

  /// Transmit power level advertised by the device, if present.
  final int? txPowerLevel;

  /// Whether the device advertises itself as connectable.
  ///
  /// Available on Android (API 26+). On iOS this is derived from
  /// `CBAdvertisementDataIsConnectable` when present, otherwise null.
  final bool? connectable;

  /// Raw manufacturer-specific data from the advertisement.
  ///
  /// On Android the leading two bytes are the company identifier (little
  /// endian). On iOS this is the raw `CBAdvertisementDataManufacturerDataKey`
  /// value, which also begins with the company identifier.
  final Uint8List? manufacturerData;

  /// Service UUIDs advertised by the device (lower-cased strings).
  final List<String> serviceUuids;

  /// Service data keyed by service UUID string.
  final Map<String, Uint8List> serviceData;

  /// Discovery timestamp in milliseconds since epoch, when available.
  final int? timestampMillis;

  /// Whether the advertisement included a non-empty local name.
  bool get hasAdvertisedName => advName.isNotEmpty;

  /// Label for UI, matching flutter_blue_plus scan list behaviour:
  /// advertised name → platform name → device id.
  String get displayName {
    if (advName.isNotEmpty) return advName;
    if (platformName.isNotEmpty) return platformName;
    return deviceId;
  }

  factory BleScanResult.fromMap(Map<dynamic, dynamic> map) {
    final rawServiceData = map['serviceData'] as Map<dynamic, dynamic>?;
    final advName = (map['advName'] as String?) ?? '';
    final platformName = (map['platformName'] as String?) ?? '';
    return BleScanResult(
      deviceId: map['deviceId']?.toString() ?? '',
      advName: advName,
      platformName: platformName,
      name: _resolveName(advName, platformName, map['name'] as String?),
      rssi: (map['rssi'] as num?)?.toInt(),
      txPowerLevel: (map['txPowerLevel'] as num?)?.toInt(),
      connectable: map['connectable'] as bool?,
      manufacturerData: _toBytes(map['manufacturerData']),
      serviceUuids: (map['serviceUuids'] as List?)
              ?.map((e) => e.toString().toLowerCase())
              .toList() ??
          const [],
      serviceData: rawServiceData == null
          ? const {}
          : rawServiceData.map(
              (key, value) => MapEntry(
                key.toString().toLowerCase(),
                _toBytes(value) ?? Uint8List(0),
              ),
            ),
      timestampMillis: (map['timestampMillis'] as num?)?.toInt(),
    );
  }

  static String? _resolveName(
    String advName,
    String platformName,
    String? legacyName,
  ) {
    if (advName.isNotEmpty && !_isPlaceholder(advName)) return advName;
    if (platformName.isNotEmpty && !_isPlaceholder(platformName)) {
      return platformName;
    }
    if (legacyName != null &&
        legacyName.isNotEmpty &&
        !_isPlaceholder(legacyName)) {
      return legacyName;
    }
    return null;
  }

  static bool _isPlaceholder(String name) {
    switch (name.toLowerCase()) {
      case 'unknown':
      case '(unknown)':
      case 'n/a':
      case 'null':
      case '<unknown>':
        return true;
      default:
        return false;
    }
  }

  static Uint8List? _toBytes(Object? value) {
    if (value == null) return null;
    if (value is Uint8List) return value;
    if (value is List) return Uint8List.fromList(value.cast<int>());
    return null;
  }

  @override
  String toString() =>
      'BleScanResult(deviceId: $deviceId, advName: $advName, '
      'platformName: $platformName, rssi: $rssi, serviceUuids: $serviceUuids)';
}
