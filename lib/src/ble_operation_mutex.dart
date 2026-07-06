/// Serializes GATT operations per device (flutter_blue_plus pattern).
class BleOperationMutex {
  BleOperationMutex._();

  static final Map<String, _Mutex> _mutexes = {};

  static Future<void> take(String deviceId) async {
    final mutex = _mutexes.putIfAbsent(deviceId, () => _Mutex());
    await mutex.take();
  }

  static void give(String deviceId) {
    _mutexes[deviceId]?.give();
  }
}

class _Mutex {
  Future<void>? _queue;
  bool _held = false;

  Future<void> take() {
    final previous = _queue ?? Future.value();
    _queue = previous.then((_) async {
      while (_held) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      _held = true;
    });
    return _queue!;
  }

  void give() {
    _held = false;
  }
}
