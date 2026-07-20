import 'package:flutter/material.dart';

import '../../domain/distance_unit.dart';
import '../../domain/imported_route.dart' show GeoPoint;
import '../../services/measurement_formatter.dart';
import '../../services/ride_summary_exporter.dart';
import 'route_sketch.dart';

/// A shareable social-media summary card for a completed ride: route shape,
/// rider count, distance, ride time, and marker passes.
class RideRecapCard extends StatelessWidget {
  const RideRecapCard({
    super.key,
    required this.summary,
    required this.routePoints,
    this.distanceUnit = DistanceUnit.kilometres,
  });

  final RideSummary summary;
  final List<GeoPoint> routePoints;
  final DistanceUnit distanceUnit;

  static const _background = Color(0xFF0D1117);
  static const _surface = Color(0xFF171D25);
  static const _accent = Color(0xFFFF7A1A);
  static const _muted = Color(0xFF8D98A7);

  @override
  Widget build(BuildContext context) {
    final formatter = MeasurementFormatter(distanceUnit);
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: _background),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'TAIL END CHARLIE',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'RIDE ${summary.rideCode}',
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: routePoints.length >= 2
                      ? CustomPaint(
                          size: Size.infinite,
                          painter: RouteSketchPainter(
                            normalizeRoutePoints(routePoints),
                          ),
                        )
                      : const Center(
                          child: Text(
                            'No recorded route for this ride',
                            style: TextStyle(color: _muted),
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _Stat(
                    icon: Icons.group_outlined,
                    label: 'Riders',
                    value: '${summary.riderCount}',
                  ),
                  _Stat(
                    icon: Icons.route_outlined,
                    label: 'Distance',
                    value: formatter.distance(summary.totalDistanceMeters),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Stat(
                    icon: Icons.timer_outlined,
                    label: 'Ride time',
                    value: _duration(summary.rideDuration),
                  ),
                  _Stat(
                    icon: Icons.flag_outlined,
                    label: 'Marker passes',
                    value: '${summary.totalConfirmedPasses}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _duration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      children: [
        Icon(icon, color: RideRecapCard._accent, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: const TextStyle(
                  color: RideRecapCard._muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
