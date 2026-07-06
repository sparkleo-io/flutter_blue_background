import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_background/flutter_blue_background.dart';
import 'package:get/get.dart';

import '../ble/ble_controller.dart';
import '../widgets/gatt_exchange_log.dart';
import '../widgets/gatt_service_tree.dart';

/// Full device view: advertisement data, connection, GATT services.
class DeviceDetailScreen extends StatelessWidget {
  const DeviceDetailScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BleController>();
    final device = controller.deviceFor(deviceId);

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.displayNameFor(deviceId)),
      ),
      body: Obx(() {
        final connectionState = controller.connectionStates[deviceId] ??
            BleConnectionState.disconnected;
        final mtu = controller.deviceMtu[deviceId];
        final services = controller.discoveredServices[deviceId] ?? const [];
        final discovering = controller.isDiscoveringServices[deviceId] ?? false;
        final isConnected = connectionState == BleConnectionState.connected;

        return ListView(
          padding: EdgeInsets.only(
              top: 16,
              right: 16,
              left: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16),
          children: [
            _Section(
              title: 'Connection',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InfoRow('deviceId', deviceId),
                  _InfoRow('stream state', connectionState.name),
                  if (mtu != null) _InfoRow('negotiated MTU', '$mtu'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: !controller.isRunning.value ||
                                  isConnected ||
                                  !controller.adapterState.value.canConnect
                              ? null
                              : () => controller.connectToDeviceId(deviceId),
                          icon: const Icon(Icons.link),
                          label: const Text('Connect'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isConnected
                              ? () => controller.disconnectFrom(deviceId)
                              : null,
                          icon: const Icon(Icons.link_off),
                          label: const Text('Disconnect'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (device != null) ...[
              const SizedBox(height: 12),
              _Section(
                title: 'Advertisement (scan result)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InfoRow('displayName', device.displayName),
                    _InfoRow('advName',
                        device.advName.isEmpty ? '—' : device.advName),
                    _InfoRow(
                      'platformName',
                      device.platformName.isEmpty ? '—' : device.platformName,
                    ),
                    _InfoRow('rssi', '${device.rssi ?? '—'} dBm'),
                    _InfoRow('txPower', '${device.txPowerLevel ?? '—'}'),
                    _InfoRow('connectable', '${device.connectable ?? '—'}'),
                    if (device.serviceUuids.isNotEmpty)
                      _InfoRow(
                        'serviceUuids',
                        device.serviceUuids.join('\n'),
                      ),
                    if (device.manufacturerData != null)
                      _InfoRow(
                        'manufacturerData',
                        device.manufacturerData!
                            .map((b) => b.toRadixString(16).padLeft(2, '0'))
                            .join(' '),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _Section(
              title: 'GATT services & characteristics',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    controller.gattStatusMessage.value,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: !isConnected || discovering
                        ? null
                        : () => controller.discoverServicesFor(deviceId),
                    child: Text(
                      discovering ? 'Discovering…' : 'discoverServices()',
                    ),
                  ),
                  if (Platform.isAndroid) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: !isConnected
                              ? null
                              : () => controller.requestMtuFor(deviceId),
                          child: const Text('requestMtu(512)'),
                        ),
                        OutlinedButton(
                          onPressed: !isConnected
                              ? null
                              : () => controller.requestConnectionPriorityFor(
                                    deviceId,
                                    ConnectionPriority.high,
                                  ),
                          child: const Text('priority: high'),
                        ),
                        OutlinedButton(
                          onPressed: !isConnected
                              ? null
                              : () => controller.requestConnectionPriorityFor(
                                    deviceId,
                                    ConnectionPriority.lowPower,
                                  ),
                          child: const Text('priority: low power'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  GattServiceTree(
                    services: services,
                    isLoading: discovering,
                    characteristicValueHex: Map<String, String>.fromEntries(
                      controller.characteristicValueHex.entries
                          .where(
                            (e) => e.key.startsWith('$deviceId|'),
                          )
                          .map(
                            (e) => MapEntry(
                                e.key.substring(deviceId.length + 1), e.value),
                          ),
                    ),
                    characteristicValueText: Map<String, String>.fromEntries(
                      controller.characteristicValueText.entries
                          .where(
                            (e) => e.key.startsWith('$deviceId|'),
                          )
                          .map(
                            (e) => MapEntry(
                                e.key.substring(deviceId.length + 1), e.value),
                          ),
                    ),
                    notifyingKeys: controller.notifyingCharacteristics
                        .where((k) => k.startsWith('$deviceId|'))
                        .map((k) => k.substring(deviceId.length + 1))
                        .toSet(),
                    onRead: isConnected
                        ? (serviceUuid, char) => controller
                            .readCharacteristicFor(deviceId, serviceUuid, char)
                        : null,
                    onWrite: isConnected
                        ? (serviceUuid, char) => _promptWrite(
                            context, controller, deviceId, serviceUuid, char)
                        : null,
                    onToggleNotify: isConnected
                        ? (serviceUuid, char) => controller.toggleNotifyFor(
                              deviceId,
                              serviceUuid,
                              char,
                            )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Sent & received',
              child: GattExchangeLog(
                entries: controller.exchangeLogFor(deviceId),
              ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Property legend',
              child: const CharacteristicPropertyChips(
                properties: [
                  'read',
                  'write',
                  'writeWithoutResponse',
                  'notify',
                  'indicate',
                ],
              ),
            ),
          ],
        );
      }),
      floatingActionButton: Obx(() {
        final connectionState = controller.connectionStates[deviceId] ??
            BleConnectionState.disconnected;
        final isConnected = connectionState == BleConnectionState.connected;
        final sending = controller.isMacCommandSending(deviceId);
        final canSend = isConnected &&
            controller.hasWritableCharacteristicForMacCommand(deviceId);

        return FloatingActionButton.extended(
          onPressed: canSend
              ? () => controller.toggleMacCommandSending(deviceId)
              : null,
          icon: Icon(sending ? Icons.stop : Icons.play_arrow),
          label: Text(sending ? 'Stop command/s' : 'Send command/s'),
        );
      }),
    );
  }
}

enum _WriteResponseMode { auto, withoutResponse, withResponse }

Future<void> _promptWrite(
  BuildContext context,
  BleController controller,
  String deviceId,
  String serviceUuid,
  BleGattCharacteristic characteristic,
) async {
  final textController = TextEditingController(text: 'mac');
  var lineEnding = '';
  var writeMode = _WriteResponseMode.auto;

  final hasWrite = characteristic.properties.contains('write');
  final hasWriteNoResp =
      characteristic.properties.contains('writeWithoutResponse');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Write text'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                'service:\n$serviceUuid',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              SelectableText(
                'characteristic:\n${characteristic.uuid}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Text to send',
                  hintText: 'mac',
                  helperText:
                      'Sends exactly what you type. Some UART-style devices '
                      'only act on a full line — try LF or CRLF below if '
                      'you get no reply.',
                ),
                autofocus: true,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 12),
              Text(
                'Line ending',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              RadioGroup<String>(
                groupValue: lineEnding,
                onChanged: (value) => setState(() => lineEnding = value ?? ''),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      dense: true,
                      title: const Text(r'None (default)'),
                      subtitle:
                          const Text('Raw bytes — works for most GATT devices'),
                      value: '',
                    ),
                    RadioListTile<String>(
                      dense: true,
                      title: const Text(r'LF (\n)'),
                      subtitle: const Text('Unix / many UART firmwares'),
                      value: '\n',
                    ),
                    RadioListTile<String>(
                      dense: true,
                      title: const Text(r'CR (\r)'),
                      value: '\r',
                    ),
                    RadioListTile<String>(
                      dense: true,
                      title: const Text(r'CRLF (\r\n)'),
                      subtitle:
                          const Text('Windows-style serial / some Leo devices'),
                      value: '\r\n',
                    ),
                  ],
                ),
              ),
              if (hasWrite && hasWriteNoResp) ...[
                const SizedBox(height: 8),
                Text(
                  'Write mode',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                RadioGroup<_WriteResponseMode>(
                  groupValue: writeMode,
                  onChanged: (value) => setState(
                    () => writeMode = value ?? _WriteResponseMode.auto,
                  ),
                  child: Column(
                    children: [
                      RadioListTile<_WriteResponseMode>(
                        dense: true,
                        title:
                            const Text('Auto (without response if available)'),
                        value: _WriteResponseMode.auto,
                      ),
                      RadioListTile<_WriteResponseMode>(
                        dense: true,
                        title: const Text('Write without response'),
                        value: _WriteResponseMode.withoutResponse,
                      ),
                      RadioListTile<_WriteResponseMode>(
                        dense: true,
                        title: const Text('Write with response'),
                        value: _WriteResponseMode.withResponse,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true) return;

  final withoutResponse = switch (writeMode) {
    _WriteResponseMode.auto => null,
    _WriteResponseMode.withoutResponse => true,
    _WriteResponseMode.withResponse => false,
  };

  await controller.writeStringFor(
    deviceId,
    serviceUuid,
    characteristic,
    textController.text,
    withoutResponse: withoutResponse,
    lineEnding: lineEnding,
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
