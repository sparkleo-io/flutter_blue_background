import 'package:flutter/material.dart';
import 'package:flutter_blue_background/flutter_blue_background.dart';

/// Colored chips for GATT characteristic property flags.
class CharacteristicPropertyChips extends StatelessWidget {
  const CharacteristicPropertyChips({
    super.key,
    required this.properties,
  });

  final List<String> properties;

  static const _colors = {
    'read': Colors.blue,
    'write': Colors.deepPurple,
    'writeWithoutResponse': Colors.purple,
    'notify': Colors.teal,
    'indicate': Colors.green,
  };

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) {
      return Text(
        'no properties',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: properties.map((prop) {
        final color = _colors[prop] ?? Theme.of(context).colorScheme.outline;
        return Chip(
          visualDensity: VisualDensity.compact,
          label: Text(prop),
          labelStyle: TextStyle(color: color, fontSize: 11),
          side: BorderSide(color: color),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }
}

typedef GattCharacteristicAction = Future<void> Function(
  String serviceUuid,
  BleGattCharacteristic characteristic,
);

/// Expandable tree of [BleGattService] and their characteristics.
class GattServiceTree extends StatelessWidget {
  const GattServiceTree({
    super.key,
    required this.services,
    this.isLoading = false,
    this.characteristicValueHex = const {},
    this.characteristicValueText = const {},
    this.notifyingKeys = const {},
    this.onRead,
    this.onWrite,
    this.onToggleNotify,
  });

  final List<BleGattService> services;
  final bool isLoading;
  final Map<String, String> characteristicValueHex;
  final Map<String, String> characteristicValueText;
  final Set<String> notifyingKeys;
  final GattCharacteristicAction? onRead;
  final GattCharacteristicAction? onWrite;
  final GattCharacteristicAction? onToggleNotify;

  static String characteristicKey(
    String serviceUuid,
    BleGattCharacteristic characteristic,
  ) =>
      '${serviceUuid.toLowerCase()}|${characteristic.uuid.toLowerCase()}|${characteristic.instanceId}';

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (services.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No services discovered yet.\n'
          'Connect to the device, then tap Discover services.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final interactive =
        onRead != null || onWrite != null || onToggleNotify != null;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: const Icon(Icons.layers_outlined),
            title: Text(
              'Service',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: SelectableText(
              service.uuid,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            children: service.characteristics.map((char) {
              final key = characteristicKey(service.uuid, char);
              final valueHex = characteristicValueHex[key];
              final valueText = characteristicValueText[key];
              final notifying = notifyingKeys.contains(key);

              return ListTile(
                dense: true,
                leading: Icon(
                  notifying
                      ? Icons.notifications_active
                      : Icons.settings_ethernet,
                  size: 20,
                  color: notifying ? Colors.teal : null,
                ),
                title: Text(
                  'Characteristic',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(char.uuid),
                    if (char.instanceId != 0)
                      Text(
                        'instanceId: ${char.instanceId}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    const SizedBox(height: 6),
                    CharacteristicPropertyChips(properties: char.properties),
                    if (valueText != null && valueText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      SelectableText(
                        'text: $valueText',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (valueHex != null) ...[
                      const SizedBox(height: 4),
                      SelectableText(
                        'hex: $valueHex',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                      ),
                    ],
                    if (interactive) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (char.canRead && onRead != null)
                            OutlinedButton.icon(
                              onPressed: () => onRead!(service.uuid, char),
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('Read'),
                            ),
                          if (char.canWrite && onWrite != null)
                            OutlinedButton.icon(
                              onPressed: () => onWrite!(service.uuid, char),
                              icon: const Icon(Icons.upload, size: 16),
                              label: const Text('Write'),
                            ),
                          if (char.canNotify && onToggleNotify != null)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  onToggleNotify!(service.uuid, char),
                              icon: Icon(
                                notifying
                                    ? Icons.notifications_off
                                    : Icons.notifications,
                                size: 16,
                              ),
                              label: Text(notifying ? 'Stop notify' : 'Notify'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
