import 'package:flutter/material.dart';
import 'package:flutter_blue_background/flutter_blue_background.dart';

/// Visual indicator for [BleAdapterState] with icon and color.
class AdapterStateIndicator extends StatelessWidget {
  const AdapterStateIndicator({
    super.key,
    required this.state,
    this.large = false,
  });

  final BleAdapterState state;
  final bool large;

  ({IconData icon, Color color, String label}) _visual(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (state) {
      BleAdapterState.on => (
          icon: Icons.bluetooth_connected,
          color: Colors.green.shade700,
          label: 'Bluetooth ON',
        ),
      BleAdapterState.off => (
          icon: Icons.bluetooth_disabled,
          color: scheme.error,
          label: 'Bluetooth OFF',
        ),
      BleAdapterState.turningOn => (
          icon: Icons.bluetooth_searching,
          color: Colors.orange.shade800,
          label: 'Turning ON…',
        ),
      BleAdapterState.turningOff => (
          icon: Icons.bluetooth_searching,
          color: Colors.orange.shade800,
          label: 'Turning OFF…',
        ),
      BleAdapterState.unauthorized => (
          icon: Icons.lock_outline,
          color: scheme.error,
          label: 'Unauthorized',
        ),
      BleAdapterState.unsupported => (
          icon: Icons.portable_wifi_off,
          color: scheme.outline,
          label: 'Unsupported',
        ),
      BleAdapterState.unknown => (
          icon: Icons.bluetooth,
          color: scheme.outline,
          label: 'Unknown',
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final visual = _visual(context);
    final iconSize = large ? 48.0 : 28.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(visual.icon, color: visual.color, size: iconSize),
        SizedBox(width: large ? 12 : 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                visual.label,
                style: large
                    ? Theme.of(context).textTheme.titleMedium
                    : Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                state.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: visual.color,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shows adapter capability flags derived from [BleAdapterState].
class AdapterCapabilityChips extends StatelessWidget {
  const AdapterCapabilityChips({super.key, required this.state});

  final BleAdapterState state;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _FlagChip('canScan', state.canScan),
        _FlagChip('canConnect', state.canConnect),
        _FlagChip('isTransitioning', state.isTransitioning),
        _FlagChip('requiresBleTeardown', state.requiresBleTeardown),
      ],
    );
  }
}

class _FlagChip extends StatelessWidget {
  const _FlagChip(this.label, this.value);

  final String label;
  final bool value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text('$label: $value'),
      backgroundColor: value
          ? Colors.green.withValues(alpha: 0.12)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}
