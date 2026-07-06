import 'package:flutter_blue_background/flutter_blue_background.dart';

/// A timestamped adapter state from the stream or a poll.
class AdapterStateLogEntry {
  const AdapterStateLogEntry({
    required this.timestamp,
    required this.state,
    required this.source,
  });

  final DateTime timestamp;
  final BleAdapterState state;

  /// `stream` from [FlutterBlueBackground.adapterState], or `poll` from
  /// [FlutterBlueBackground.getAdapterState].
  final String source;
}

/// A timestamped [BleConnectionEvent] from the connection stream.
class ConnectionLogEntry {
  const ConnectionLogEntry({
    required this.timestamp,
    required this.event,
  });

  final DateTime timestamp;
  final BleConnectionEvent event;
}
