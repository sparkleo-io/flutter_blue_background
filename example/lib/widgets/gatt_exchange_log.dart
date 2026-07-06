import 'package:flutter/material.dart';

import '../ble/ble_gatt_exchange_entry.dart';

/// Scrollable sent/received GATT exchange log for a device.
class GattExchangeLog extends StatelessWidget {
  const GattExchangeLog({
    super.key,
    required this.entries,
  });

  final List<GattExchangeEntry> entries;

  static String _formatTime(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No data sent or received yet.\n'
          'Write to RX, enable notify on TX. UART-style devices may need '
          'a line ending (LF or CRLF) before they respond.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final color = entry.isSent ? Colors.deepPurple : Colors.teal;
        final icon = entry.isSent ? Icons.arrow_upward : Icons.arrow_downward;
        return ListTile(
          dense: true,
          leading: Icon(icon, color: color, size: 18),
          title: Text(
            entry.isSent ? 'Sent' : 'Received',
            style:
                Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_formatTime(entry.timestamp)} · ${entry.source}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              SelectableText(
                'service: ${entry.serviceUuid}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              SelectableText(
                'characteristic: ${entry.characteristicUuid}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              SelectableText(
                entry.text.isEmpty ? '(non-text bytes)' : entry.text,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SelectableText(
                entry.hex,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}
