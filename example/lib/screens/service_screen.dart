import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ble/ble_controller.dart';
import '../widgets/ble_status_banner.dart';

class ServiceScreen extends StatelessWidget {
  const ServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BleController>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const BleStatusBanner(),
          const SizedBox(height: 24),
          Text(
            'Foreground service',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Start the native background service before scanning or connecting. '
            'On Android this shows a persistent notification that updates with '
            'adapter, scan, and connection state.',
          ),
          const SizedBox(height: 16),
          Obx(
            () => Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: controller.isRunning.value
                        ? null
                        : controller.startService,
                    child: const Text('startService()'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.isRunning.value
                        ? controller.stopService
                        : null,
                    child: const Text('stopService()'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Platform & flags',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Obx(
            () => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FlagRow(
                      'getPlatformVersion()',
                      controller.platformVersion.value ?? '—',
                    ),
                    _FlagRow(
                      'isServiceRunning()',
                      '${controller.isRunning.value}',
                    ),
                    _FlagRow(
                      'isScanning()',
                      '${controller.isScanning.value}',
                    ),
                    _FlagRow(
                      'adapterState (stream)',
                      controller.adapterState.value.name,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.fetchPlatformVersion,
                  child: const Text('Refresh version'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.refreshServiceFlags,
                  child: const Text('Refresh flags'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlagRow extends StatelessWidget {
  const _FlagRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            flex: 2,
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
