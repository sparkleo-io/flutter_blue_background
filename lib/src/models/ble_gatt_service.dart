import 'ble_gatt_descriptor.dart';

/// A discovered GATT characteristic on a connected device.
class BleGattCharacteristic {
  const BleGattCharacteristic({
    required this.uuid,
    this.instanceId = 0,
    this.properties = const [],
    this.descriptors = const [],
  });

  final String uuid;
  final int instanceId;
  final List<String> properties;
  final List<BleGattDescriptor> descriptors;

  bool get canRead => properties.contains('read');
  bool get canWrite =>
      properties.contains('write') ||
      properties.contains('writeWithoutResponse');
  bool get canNotify =>
      properties.contains('notify') || properties.contains('indicate');

  factory BleGattCharacteristic.fromMap(Map<dynamic, dynamic> map) {
    final rawProps = map['properties'];
    final rawDesc = map['descriptors'];
    return BleGattCharacteristic(
      uuid: map['uuid'] as String,
      instanceId: (map['instanceId'] as num?)?.toInt() ?? 0,
      properties: rawProps is List
          ? rawProps.map((e) => e.toString()).toList()
          : const [],
      descriptors: rawDesc is List
          ? rawDesc
              .map((e) => BleGattDescriptor.fromMap(e as Map<dynamic, dynamic>))
              .toList()
          : const [],
    );
  }
}

/// A discovered GATT service on a connected device.
class BleGattService {
  const BleGattService({
    required this.uuid,
    this.characteristics = const [],
  });

  final String uuid;
  final List<BleGattCharacteristic> characteristics;

  factory BleGattService.fromMap(Map<dynamic, dynamic> map) {
    final rawChars = map['characteristics'];
    return BleGattService(
      uuid: map['uuid'] as String,
      characteristics: rawChars is List
          ? rawChars
              .map((e) =>
                  BleGattCharacteristic.fromMap(e as Map<dynamic, dynamic>))
              .toList()
          : const [],
    );
  }
}
