/// A discovered GATT descriptor on a characteristic.
class BleGattDescriptor {
  const BleGattDescriptor({required this.uuid});

  final String uuid;

  factory BleGattDescriptor.fromMap(Map<dynamic, dynamic> map) {
    return BleGattDescriptor(uuid: map['uuid'] as String);
  }
}
