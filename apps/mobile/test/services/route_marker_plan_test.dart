import 'package:flutter_test/flutter_test.dart';
import 'package:ride_relay/domain/imported_route.dart';
import 'package:ride_relay/services/route_marker_plan.dart';

void main() {
  const analyzer = RouteMarkerPlanAnalyzer();

  test('applies default marker rules and separates unsafe junctions', () {
    final plan = analyzer.analyze(
      _route(
        maneuvers: const [
          RouteManeuver(
            position: GeoPoint(latitude: 51, longitude: -2),
            type: 'turn',
            modifier: 'straight',
          ),
          RouteManeuver(
            position: GeoPoint(latitude: 51.1, longitude: -2.1),
            type: 'turn',
            modifier: 'left',
          ),
          RouteManeuver(
            position: GeoPoint(latitude: 51.2, longitude: -2.2),
            type: 'roundabout',
            modifier: 'right',
            exitNumber: 3,
          ),
          RouteManeuver(
            position: GeoPoint(latitude: 51.3, longitude: -2.3),
            type: 'off ramp',
            modifier: 'left',
          ),
        ],
      ),
    );

    expect(plan.likelyMarkers, hasLength(2));
    expect(
      plan.likelyMarkers.map((point) => point.label),
      containsAll(['Turn left marker', 'Roundabout exit 3 marker']),
    );
    expect(plan.safetyReviews.single.label, contains('exit review'));
  });

  test('flags multi-lane roundabouts for leader safety review', () {
    final plan = analyzer.analyze(
      _route(
        maneuvers: const [
          RouteManeuver(
            position: GeoPoint(latitude: 51.2, longitude: -2.2),
            type: 'roundabout',
            modifier: 'right',
            lanes: [
              RouteLane(indications: ['left'], valid: false),
              RouteLane(indications: ['straight'], valid: false),
              RouteLane(indications: ['right'], valid: true),
            ],
          ),
        ],
      ),
    );

    expect(plan.likelyMarkers, isEmpty);
    expect(plan.safetyReviews.single.detail, contains('multi-lane'));
  });

  test('recognises an explicit muster waypoint', () {
    final plan = analyzer.analyze(
      _route(
        waypoints: const [
          RouteWaypoint(
            point: GeoPoint(latitude: 51.15, longitude: -2.15),
            name: 'Village muster point',
          ),
        ],
      ),
    );

    expect(plan.musterPoints.single.label, 'Village muster point');
  });
}

ImportedRoute _route({
  List<RouteManeuver> maneuvers = const [],
  List<RouteWaypoint> waypoints = const [],
}) => ImportedRoute(
  id: 'route',
  name: 'Marker plan',
  importedAt: DateTime.utc(2026, 7, 24),
  sourceFileName: 'marker-plan.gpx',
  paths: const [
    RoutePath(
      kind: RoutePathKind.track,
      points: [
        GeoPoint(latitude: 51, longitude: -2),
        GeoPoint(latitude: 51.4, longitude: -2.4),
      ],
    ),
  ],
  waypoints: waypoints,
  maneuvers: maneuvers,
);
