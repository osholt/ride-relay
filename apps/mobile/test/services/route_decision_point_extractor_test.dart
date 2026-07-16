import 'package:flutter_test/flutter_test.dart';
import 'package:ride_relay/domain/geo_point.dart';
import 'package:ride_relay/domain/marker_assistance.dart';
import 'package:ride_relay/services/route_decision_point_extractor.dart';

void main() {
  test('combines explicit waypoints with spaced geometric turns', () {
    final points = const RouteDecisionPointExtractor().extract(
      route: const [
        GeoPoint(latitude: 51, longitude: -1),
        GeoPoint(latitude: 51, longitude: -0.998),
        GeoPoint(latitude: 51.002, longitude: -0.998),
      ],
      explicitPoints: const [
        ExplicitDecisionPoint(
          position: GeoPoint(latitude: 51.001, longitude: -0.999),
          label: 'Named junction',
        ),
      ],
    );

    expect(points, hasLength(2));
    expect(points.first.source, DecisionPointSource.waypoint);
    expect(points.last.source, DecisionPointSource.routeGeometry);
  });

  test('does not treat a straight route as a decision point', () {
    final points = const RouteDecisionPointExtractor().extract(
      route: const [
        GeoPoint(latitude: 51, longitude: -1),
        GeoPoint(latitude: 51, longitude: -0.999),
        GeoPoint(latitude: 51, longitude: -0.998),
      ],
    );

    expect(points, isEmpty);
  });
}
