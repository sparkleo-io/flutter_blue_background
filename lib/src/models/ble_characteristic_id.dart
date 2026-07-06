/// Identifies a GATT characteristic on a connected device.
class BleCharacteristicId {
  const BleCharacteristicId({
    required this.serviceUuid,
    required this.characteristicUuid,
    this.instanceId = 0,
  });

  final String serviceUuid;
  final String characteristicUuid;

  /// Distinguishes duplicate characteristics in the same service (Android).
  final int instanceId;

  Map<String, dynamic> toMap() => {
        'serviceUuid': serviceUuid,
        'characteristicUuid': characteristicUuid,
        'instanceId': instanceId,
      };

  factory BleCharacteristicId.fromMap(Map<dynamic, dynamic> map) {
    return BleCharacteristicId(
      serviceUuid: map['serviceUuid'] as String,
      characteristicUuid: map['characteristicUuid'] as String,
      instanceId: (map['instanceId'] as num?)?.toInt() ?? 0,
    );
  }
}
