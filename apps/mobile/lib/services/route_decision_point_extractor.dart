import 'dart:math' as math;

import '../domain/geo_point.dart';
import '../domain/marker_assistance.dart';
import 'geo_calculations.dart';

class ExplicitDecisionPoint {
  const ExplicitDecisionPoint({required this.position, this.label});

  final GeoPoint position;
  final String? label;
}

class RouteDecisionPointConfig {
  const RouteDecisionPointConfig({
    this.minimumTurnDegrees = 35,
    this.minimumSpacingMeters = 80,
  });

  final double minimumTurnDegrees;
  final double minimumSpacingMeters;
}

class RouteDecisionPointExtractor {
  const RouteDecisionPointExtractor({
    this.config = const RouteDecisionPointConfig(),
  });

  final RouteDecisionPointConfig config;

  List<RouteDecisionPoint> extract({
    required List<GeoPoint> route,
    List<ExplicitDecisionPoint> explicitPoints = const [],
  }) {
    final result = <RouteDecisionPoint>[];
    for (var index = 0; index < explicitPoints.length; index += 1) {
      final point = explicitPoints[index];
      result.add(
        RouteDecisionPoint(
          id: 'waypoint-$index',
          position: point.position,
          source: DecisionPointSource.waypoint,
          label: point.label,
        ),
      );
    }

    for (var index = 1; index < route.length - 1; index += 1) {
      final point = route[index];
      final inbound = _bearing(route[index - 1], point);
      final outbound = _bearing(point, route[index + 1]);
      final turn = _smallestAngle(inbound, outbound);
      if (turn < config.minimumTurnDegrees ||
          result.any(
            (existing) =>
                GeoCalculations.distanceMeters(existing.position, point) <
                config.minimumSpacingMeters,
          )) {
        continue;
      }
      result.add(
        RouteDecisionPoint(
          id: 'turn-$index',
          position: point,
          source: DecisionPointSource.routeGeometry,
          label: '${turn.round()}° route turn',
        ),
      );
    }
    return List.unmodifiable(result);
  }

  static double _bearing(GeoPoint from, GeoPoint to) {
    final latitude1 = _radians(from.latitude);
    final latitude2 = _radians(to.latitude);
    final longitudeDelta = _radians(to.longitude - from.longitude);
    final y = math.sin(longitudeDelta) * math.cos(latitude2);
    final x =
        math.cos(latitude1) * math.sin(latitude2) -
        math.sin(latitude1) * math.cos(latitude2) * math.cos(longitudeDelta);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static double _smallestAngle(double first, double second) {
    final difference = (second - first).abs() % 360;
    return difference > 180 ? 360 - difference : difference;
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
