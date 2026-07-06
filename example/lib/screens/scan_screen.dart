import 'package:flutter/material.dart';
import 'package:flutter_blue_background/flutter_blue_background.dart';
import 'package:get/get.dart';

import '../ble/ble_controller.dart';
import 'device_detail_screen.dart';
import '../widgets/ble_status_banner.dart';

class ScanDeviceTile extends StatelessWidget {
  const ScanDeviceTile({
    super.key,
    required this.device,
    required this.connectionState,
    required this.onConnect,
    required this.onDisconnect,
    required this.onOpenDetail,
    required this.canConnect,
    required this.serviceRunning,
    this.serviceCount,
  });

  final BleScanResult device;
  final BleConnectionState connectionState;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onOpenDetail;
  final bool canConnect;
  final bool serviceRunning;
  final int? serviceCount;

  @override
  Widget build(BuildContext context) {
    final isConnected = connectionState == BleConnectionState.connected;
    final isBusy = connectionState == BleConnectionState.connecting ||
        connectionState == BleConnectionState.disconnecting;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onOpenDetail,
        leading: SizedBox(
          width: 40,
          height: 40,
          child: isBusy
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  tooltip: isConnected ? 'Disconnect' : 'Connect',
                  icon: Icon(
                    isConnected ? Icons.link_off : Icons.link,
                    size: 20,
                  ),
                  onPressed: !serviceRunning || (!canConnect && !isConnected)
                      ? null
                      : (isConnected ? onDisconnect : onConnect),
                ),
        ),
        title: Text(device.displayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.deviceId, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              [
                connectionState.name,
                if (serviceCount != null) '$serviceCount GATT service(s)',
                if (device.serviceUuids.isNotEmpty)
                  '${device.serviceUuids.length} adv UUID(s)',
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${device.rssi ?? '--'} dBm'),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BleController>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BleStatusBanner(),
          const SizedBox(height: 16),
          Obx(
            () => Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: !controller.isRunning.value ||
                            controller.isScanning.value ||
                            !controller.adapterState.value.canScan
                        ? null
                        : controller.startScan,
                    child: const Text('Start scan'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.isScanning.value
                        ? controller.stopScan
                        : null,
                    child: const Text('Stop scan'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.refreshCachedScanResults,
                  child: const Text('getScanResults()'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.clearCachedScanResults,
                  child: const Text('clearScanResults()'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Obx(
            () => Text(
              'Discovered devices (${controller.devices.length}) — tap for details',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const Divider(),
          Expanded(
            child: Obx(() {
              final devices = controller.sortedDevices;
              if (devices.isEmpty) {
                return const Center(
                  child: Text('No devices yet — start a scan'),
                );
              }

              return ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  final connectionState =
                      controller.connectionStates[device.deviceId] ??
                          BleConnectionState.disconnected;
                  final gattCount =
                      controller.discoveredServices[device.deviceId]?.length;

                  return ScanDeviceTile(
                    device: device,
                    connectionState: connectionState,
                    serviceCount: gattCount,
                    serviceRunning: controller.isRunning.value,
                    canConnect: controller.adapterState.value.canConnect,
                    onConnect: () => controller.connectTo(device),
                    onDisconnect: () =>
                        controller.disconnectFrom(device.deviceId),
                    onOpenDetail: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            DeviceDetailScreen(deviceId: device.deviceId),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
