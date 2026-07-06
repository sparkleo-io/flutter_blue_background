import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ble/ble_controller.dart';
import '../widgets/adapter_state_indicator.dart';
import '../widgets/ble_event_log.dart';

class AdapterScreen extends StatelessWidget {
  const AdapterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BleController>();

    return Obx(() {
      final streamState = controller.adapterState.value;
      final polled = controller.polledAdapterState.value;

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Live adapter stream',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  AdapterStateIndicator(state: streamState, large: true),
                  const SizedBox(height: 12),
                  const Text(
                    'Updates automatically from FlutterBlueBackground.adapterState '
                    'when Bluetooth turns on/off or transitions.',
                  ),
                  const SizedBox(height: 12),
                  AdapterCapabilityChips(state: streamState),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Poll adapter state',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Calls getAdapterState() once and compares with the stream.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: controller.fetchAdapterState,
                    child: const Text('getAdapterState()'),
                  ),
                  if (polled != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Polled: '),
                        Text(
                          polled.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: polled == streamState
                                ? Colors.green.shade700
                                : Colors.orange.shade800,
                          ),
                        ),
                        if (polled != streamState) ...[
                          const SizedBox(width: 8),
                          const Text('(differs from stream)'),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Adapter event log',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              TextButton(
                onPressed: controller.clearLogs,
                child: const Text('Clear logs'),
              ),
            ],
          ),
          Card(
            child: BleEventLogList(
              adapterEntries: controller.adapterStateLog.toList(),
              connectionEntries: const [],
              showConnection: false,
            ),
          ),
        ],
      );
    });
  }
}
