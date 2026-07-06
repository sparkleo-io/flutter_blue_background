import 'package:flutter/material.dart';
import 'package:flutter_blue_background/flutter_blue_background.dart';
import 'package:get/get.dart';

import '../ble/ble_controller.dart';
import '../widgets/adapter_state_indicator.dart';

/// Compact service + adapter + status strip used at the top of each tab.
class BleStatusBanner extends StatelessWidget {
  const BleStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BleController>();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    controller.isRunning.value
                        ? Icons.play_circle
                        : Icons.stop_circle_outlined,
                    size: 18,
                    color: controller.isRunning.value
                        ? Colors.green.shade700
                        : Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.isRunning.value
                          ? 'Service RUNNING'
                          : 'Service STOPPED',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (controller.isScanning.value)
                    const Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('SCAN'),
                    ),
                ],
              ),
              const Divider(height: 16),
              AdapterStateIndicator(state: controller.adapterState.value),
              const SizedBox(height: 8),
              Text(
                controller.status.value,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Human-readable label for a [BleConnectionState] with stream vs polled hint.
class ConnectionStateChip extends StatelessWidget {
  const ConnectionStateChip({
    super.key,
    required this.label,
    required this.state,
    this.compact = false,
  });

  final String label;
  final BleConnectionState state;
  final bool compact;

  Color _color(BuildContext context) {
    return switch (state) {
      BleConnectionState.connected => Colors.green.shade700,
      BleConnectionState.connecting => Colors.orange.shade800,
      BleConnectionState.disconnecting => Colors.orange.shade800,
      BleConnectionState.disconnected => Theme.of(context).colorScheme.outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      label: Text('$label: ${state.name}'),
      labelStyle: TextStyle(
        color: _color(context),
        fontSize: compact ? 11 : 12,
      ),
      side: BorderSide(color: _color(context)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
