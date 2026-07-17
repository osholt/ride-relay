import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/distance_unit_controller.dart';
import '../../domain/distance_unit.dart';
import '../../services/basemap_configuration.dart';

class UnitSettingsSheet extends StatelessWidget {
  const UnitSettingsSheet({super.key, required this.controller});

  final DistanceUnitController controller;

  static Future<void> show(
    BuildContext context,
    DistanceUnitController controller,
  ) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => UnitSettingsSheet(controller: controller),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          Text(
            'DISTANCE UNITS',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF8D98A7),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<DistanceUnit>(
            key: const Key('distance-unit-selector'),
            segments: DistanceUnit.values
                .map(
                  (unit) => ButtonSegment<DistanceUnit>(
                    value: unit,
                    label: Text(unit.label),
                  ),
                )
                .toList(growable: false),
            selected: {controller.value},
            onSelectionChanged: (selection) {
              unawaited(controller.setUnit(selection.single));
            },
          ),
          const SizedBox(height: 12),
          Text(
            controller.followsLocale
                ? 'Using the device locale default (${controller.localeDefault.label.toLowerCase()}).'
                : 'Overriding the device locale default (${controller.localeDefault.label.toLowerCase()}).',
            style: const TextStyle(color: Color(0xFF98A3B1)),
          ),
          if (!controller.followsLocale) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('use-locale-distance-unit'),
                onPressed: () => unawaited(controller.useLocaleDefault()),
                child: const Text('Use locale default'),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Text(
            'MAP DATA',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF8D98A7),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            BasemapConfiguration.fromEnvironment().attribution,
            style: const TextStyle(color: Color(0xFF98A3B1), fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
