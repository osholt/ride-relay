import 'package:flutter/material.dart';

import '../../controllers/nearby_relay_controller.dart';
import '../../relay/relay_engine.dart';

class RelayStatusCard extends StatelessWidget {
  const RelayStatusCard({required this.controller, super.key});

  final NearbyRelayController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final status = controller.status;
      final (icon, label) = switch (status.state) {
        RelayConnectionState.connected => (
          Icons.bluetooth_connected,
          '${status.peerIds.length} nearby',
        ),
        RelayConnectionState.searching => (Icons.radar, 'Searching nearby'),
        RelayConnectionState.backingOff => (
          Icons.sync_problem,
          'Reconnecting automatically',
        ),
        RelayConnectionState.unavailable => (
          Icons.bluetooth_disabled,
          'Nearby unavailable',
        ),
        RelayConnectionState.failed => (Icons.error_outline, 'Nearby error'),
        RelayConnectionState.starting => (Icons.sync, 'Starting nearby'),
        RelayConnectionState.stopped => (Icons.bluetooth, 'Nearby stopped'),
      };
      return Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          subtitle: Text(
            '${status.queuedEventCount} queued · development alpha',
          ),
        ),
      );
    },
  );
}
