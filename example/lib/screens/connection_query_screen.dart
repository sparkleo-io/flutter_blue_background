import 'package:flutter/material.dart';
import 'package:flutter_blue_background/flutter_blue_background.dart';
import 'package:get/get.dart';

import '../ble/ble_controller.dart';
import '../widgets/ble_event_log.dart';
import '../widgets/ble_status_banner.dart';
import 'device_detail_screen.dart';

class ConnectionQueryScreen extends StatefulWidget {
  const ConnectionQueryScreen({super.key});

  @override
  State<ConnectionQueryScreen> createState() => _ConnectionQueryScreenState();
}

class _ConnectionQueryScreenState extends State<ConnectionQueryScreen> {
  final _deviceIdController = TextEditingController();

  @override
  void dispose() {
    _deviceIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BleController>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BleStatusBanner(),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                Text(
                  'Connection queries',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Obx(
                  () => FilledButton.icon(
                    onPressed: controller.isQueryingConnections.value
                        ? null
                        : controller.fetchConnectedDevices,
                    icon: const Icon(Icons.devices),
                    label: const Text('getConnectedDevices()'),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() {
                  final ids = controller.queriedConnectedDeviceIds.toList();
                  if (ids.isEmpty) return const SizedBox.shrink();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Connected (${ids.length})',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          ...ids.map(SelectableText.new),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                TextField(
                  controller: _deviceIdController,
                  decoration: const InputDecoration(
                    labelText: 'Device id',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(
                  () => Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: controller.isQueryingConnections.value
                              ? null
                              : () => controller.fetchConnectionState(
                                    _deviceIdController.text.trim(),
                                  ),
                          child: const Text('getConnectionState()'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: controller.isQueryingConnections.value
                              ? null
                              : controller.fetchAllKnownConnectionStates,
                          child: const Text('Query all'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Obx(
                  () => Text(
                    controller.queryStatusMessage.value,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Devices',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Obx(() {
                  // Touch RxMaps/RxLists so GetX registers dependencies.
                  final deviceIds = <String>{
                    ...controller.devices.keys,
                    ...controller.connectionStates.keys,
                    ...controller.queriedConnectedDeviceIds,
                  }.toList()
                    ..sort();
                  final connectionStates = controller.connectionStates;
                  final queriedStates = controller.queriedConnectionStates;
                  final gattServices = controller.discoveredServices;

                  if (deviceIds.isEmpty) {
                    return const Text('Scan or connect first');
                  }

                  return Column(
                    children: deviceIds.map((deviceId) {
                      final streamState = connectionStates[deviceId] ??
                          BleConnectionState.disconnected;
                      final polled = queriedStates[deviceId];
                      final gatt = gattServices[deviceId]?.length;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(controller.displayNameFor(deviceId)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(deviceId),
                              Wrap(
                                spacing: 4,
                                children: [
                                  ConnectionStateChip(
                                    label: 'stream',
                                    state: streamState,
                                    compact: true,
                                  ),
                                  if (polled != null)
                                    ConnectionStateChip(
                                      label: 'polled',
                                      state: polled,
                                      compact: true,
                                    ),
                                ],
                              ),
                              if (gatt != null)
                                Text('$gatt GATT service(s) discovered'),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  DeviceDetailScreen(deviceId: deviceId),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'connectionState stream log',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: controller.clearLogs,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                Obx(() {
                  final entries = controller.connectionEventLog.toList();
                  if (entries.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No connection events yet'),
                      ),
                    );
                  }
                  return Card(
                    child: BleEventLogList(
                      adapterEntries: const [],
                      connectionEntries: entries,
                      showAdapter: false,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
