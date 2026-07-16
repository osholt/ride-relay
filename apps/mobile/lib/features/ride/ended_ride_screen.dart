import 'package:flutter/material.dart';

import '../../controllers/internet_relay_controller.dart';
import '../../controllers/nearby_relay_controller.dart';
import '../../controllers/ride_controller.dart';
import '../../services/ride_summary_exporter.dart';
import '../internet/internet_relay_status_card.dart';
import '../nearby/relay_status_card.dart';

class EndedRideScreen extends StatelessWidget {
  const EndedRideScreen({
    super.key,
    required this.controller,
    this.nearbyRelayController,
    this.internetRelayController,
    this.summarySharer,
  });

  final RideController controller;
  final NearbyRelayController? nearbyRelayController;
  final InternetRelayController? internetRelayController;
  final RideSummarySharer? summarySharer;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ride ended')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          'Ride summary ready',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Location sharing is stopped. Relay recovery stays available so the '
          'final marker and ride-ended events can still be delivered after a '
          'temporary loss of signal.',
          style: TextStyle(color: Color(0xFFABB5C1), height: 1.45),
        ),
        const SizedBox(height: 18),
        if (nearbyRelayController case final nearby?) ...[
          RelayStatusCard(controller: nearby),
          const SizedBox(height: 12),
        ],
        if (internetRelayController case final internet?) ...[
          InternetRelayStatusCard(controller: internet),
          const SizedBox(height: 18),
        ],
        FilledButton.icon(
          onPressed: () => _shareSummary(context),
          icon: const Icon(Icons.ios_share),
          label: const Text('Share ride summary'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _confirmRemove(context),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Remove ride from this phone'),
        ),
      ],
    ),
  );

  Future<void> _shareSummary(BuildContext context) async {
    final renderObject = context.findRenderObject();
    final origin = renderObject is RenderBox && renderObject.hasSize
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;
    try {
      await (summarySharer ?? const SystemRideSummarySharer()).share(
        controller.session!,
        controller.events,
        sharePositionOrigin: origin,
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share ride summary: $error')),
      );
    }
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this ended ride?'),
        content: const Text(
          'Automatic relay recovery for its final events will stop on this '
          'phone. Export the summary first if you want a copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep ride'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await controller.clearEndedRide();
  }
}
