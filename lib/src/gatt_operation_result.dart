import 'dart:typed_data';

import 'fbb_exception.dart';

/// Parses native GATT operation result maps into Dart values or [FbbException].
class GattOperationResult {
  GattOperationResult._();

  static Uint8List parseRead(String method, Map<dynamic, dynamic>? map) {
    _ensureSuccess(method, map);
    final rawValue = map!['value'];
    if (rawValue is Uint8List) return rawValue;
    if (rawValue is List) {
      return Uint8List.fromList(rawValue.cast<int>());
    }
    return Uint8List(0);
  }

  static void parseVoid(String method, Map<dynamic, dynamic>? map) {
    _ensureSuccess(method, map);
  }

  static void parseSetNotify(String method, Map<dynamic, dynamic>? map) {
    _ensureSuccess(method, map);
    final cccdWritten = map!['cccdWritten'] as bool?;
    if (cccdWritten == false) {
      throw FbbException(
        method,
        'FBB: CCCD descriptor was not written — notifications are not active',
      );
    }
  }

  static void _ensureSuccess(String method, Map<dynamic, dynamic>? map) {
    if (map == null) {
      throw FbbException(method, 'FBB: No response from native layer');
    }
    final success = map['success'] as bool? ?? false;
    if (success) return;

    final message =
        map['errorMessage'] as String? ?? 'FBB: GATT operation failed';
    throw FbbException(
      method,
      message.startsWith('FBB:') ? message : 'FBB: $message',
      errorCode: (map['errorCode'] as num?)?.toInt(),
    );
  }
}
