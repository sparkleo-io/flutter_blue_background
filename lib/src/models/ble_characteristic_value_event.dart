import 'dart:typed_data';

import 'ble_characteristic_id.dart';

/// How a [BleCharacteristicValueEvent] was produced.
enum BleCharacteristicValueSource {
  read,
  write,
  notification;

  static BleCharacteristicValueSource fromNative(String? value) {
    if (value == null) return BleCharacteristicValueSource.notification;
    for (final source in BleCharacteristicValueSource.values) {
      if (source.name == value) return source;
    }
    return BleCharacteristicValueSource.notification;
  }
}

/// A characteristic value from read, write confirmation, or notification.
class BleCharacteristicValueEvent {
  const BleCharacteristicValueEvent({
    required this.deviceId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.instanceId,
    required this.value,
    required this.source,
    this.success = true,
    this.errorCode,
    this.errorMessage,
  });

  final String deviceId;
  final String serviceUuid;
  final String characteristicUuid;
  final int instanceId;
  final Uint8List value;
  final BleCharacteristicValueSource source;
  final bool success;
  final int? errorCode;
  final String? errorMessage;

  BleCharacteristicId get characteristicId => BleCharacteristicId(
        serviceUuid: serviceUuid,
        characteristicUuid: characteristicUuid,
        instanceId: instanceId,
      );

  factory BleCharacteristicValueEvent.fromMap(Map<dynamic, dynamic> map) {
    final rawValue = map['value'];
    Uint8List bytes;
    if (rawValue is Uint8List) {
      bytes = rawValue;
    } else if (rawValue is List) {
      bytes = Uint8List.fromList(rawValue.cast<int>());
    } else {
      bytes = Uint8List(0);
    }

    return BleCharacteristicValueEvent(
      deviceId: map['deviceId'] as String,
      serviceUuid: map['serviceUuid'] as String,
      characteristicUuid: map['characteristicUuid'] as String,
      instanceId: (map['instanceId'] as num?)?.toInt() ?? 0,
      value: bytes,
      source: BleCharacteristicValueSource.fromNative(map['source'] as String?),
      success: map['success'] as bool? ?? true,
      errorCode: (map['errorCode'] as num?)?.toInt(),
      errorMessage: map['errorMessage'] as String?,
    );
  }
}
