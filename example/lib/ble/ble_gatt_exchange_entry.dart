/// A sent or received GATT payload shown in the example exchange log.
class GattExchangeEntry {
  const GattExchangeEntry({
    required this.timestamp,
    required this.deviceId,
    required this.direction,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.text,
    required this.hex,
    required this.source,
  });

  final DateTime timestamp;
  final String deviceId;

  /// `sent` or `received`.
  final String direction;
  final String serviceUuid;
  final String characteristicUuid;
  final String text;
  final String hex;
  final String source;

  bool get isSent => direction == 'sent';
}
