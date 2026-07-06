import 'package:flutter/material.dart';
import 'package:flutter_blue_background/flutter_blue_background.dart';

import '../ble/ble_log_entry.dart';

/// Scrollable list of timestamped BLE log entries.
class BleEventLogList extends StatelessWidget {
  const BleEventLogList({
    super.key,
    required this.adapterEntries,
    required this.connectionEntries,
    this.showAdapter = true,
    this.showConnection = true,
  });

  final List<AdapterStateLogEntry> adapterEntries;
  final List<ConnectionLogEntry> connectionEntries;
  final bool showAdapter;
  final bool showConnection;

  static String _formatTime(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(time.hour);
    final m = two(time.minute);
    final s = two(time.second);
    final ms = time.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  @override
  Widget build(BuildContext context) {
    final items = <_LogRow>[];

    if (showAdapter) {
      for (final entry in adapterEntries) {
        items.add(
          _LogRow(
            time: entry.timestamp,
            icon: Icons.bluetooth,
            color: Colors.blue,
            title: 'adapterState [${entry.source}]',
            subtitle: entry.state.name,
          ),
        );
      }
    }

    if (showConnection) {
      for (final entry in connectionEntries) {
        final event = entry.event;
        items.add(
          _LogRow(
            time: entry.timestamp,
            icon: Icons.link,
            color: event.state == BleConnectionState.connected
                ? Colors.green.shade700
                : Colors.grey,
            title: 'connectionState — ${event.deviceId}',
            subtitle: [
              event.state.name,
              if (event.mtu != null) 'mtu ${event.mtu}',
              if (event.errorMessage != null) event.errorMessage!,
              if (event.errorCode != null) 'code ${event.errorCode}',
            ].join(' · '),
          ),
        );
      }
    }

    items.sort((a, b) => b.time.compareTo(a.time));

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No events logged yet'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final row = items[index];
        return ListTile(
          dense: true,
          leading: Icon(row.icon, color: row.color, size: 20),
          title: Text(row.title, style: Theme.of(context).textTheme.bodySmall),
          subtitle: Text(row.subtitle),
          trailing: Text(
            _formatTime(row.time),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        );
      },
    );
  }
}

class _LogRow {
  _LogRow({
    required this.time,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final DateTime time;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
}
