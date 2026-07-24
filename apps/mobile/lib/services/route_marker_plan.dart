import '../domain/imported_route.dart';

enum MarkerPlanPointKind { likelyMarker, safetyReview, musterPoint }

class MarkerPlanningRules {
  const MarkerPlanningRules({
    this.markStraightTurns = false,
    this.markRoundabouts = true,
    this.roundaboutEntryAndExit = false,
    this.multiLaneRoundaboutThreshold = 3,
  });

  final bool markStraightTurns;
  final bool markRoundabouts;
  final bool roundaboutEntryAndExit;
  final int multiLaneRoundaboutThreshold;
}

class MarkerPlanPoint {
  const MarkerPlanPoint({
    required this.id,
    required this.position,
    required this.kind,
    required this.label,
    this.detail,
  });

  final String id;
  final GeoPoint position;
  final MarkerPlanPointKind kind;
  final String label;
  final String? detail;
}

class RouteMarkerPlan {
  const RouteMarkerPlan({required this.points});

  final List<MarkerPlanPoint> points;

  List<MarkerPlanPoint> get likelyMarkers => points
      .where((point) => point.kind == MarkerPlanPointKind.likelyMarker)
      .toList(growable: false);

  List<MarkerPlanPoint> get safetyReviews => points
      .where((point) => point.kind == MarkerPlanPointKind.safetyReview)
      .toList(growable: false);

  List<MarkerPlanPoint> get musterPoints => points
      .where((point) => point.kind == MarkerPlanPointKind.musterPoint)
      .toList(growable: false);
}

/// Produces a deliberately conservative pre-ride marker estimate.
///
/// It uses route-engine manoeuvres rather than bends in GPX geometry. A safety
/// review point is never counted as a suggested place to stop: the ride leader
/// must inspect the junction and choose a legal, visible place away from live
/// lanes.
class RouteMarkerPlanAnalyzer {
  const RouteMarkerPlanAnalyzer({this.rules = const MarkerPlanningRules()});

  final MarkerPlanningRules rules;

  RouteMarkerPlan analyze(ImportedRoute route) {
    final points = <MarkerPlanPoint>[];
    for (final entry in route.maneuvers.indexed) {
      final maneuver = entry.$2;
      final type = maneuver.type.trim().toLowerCase();
      final modifier = maneuver.modifier?.trim().toLowerCase() ?? '';
      final id = 'maneuver-${entry.$1}';

      if (const {'merge', 'on ramp', 'off ramp'}.contains(type)) {
        points.add(
          MarkerPlanPoint(
            id: id,
            position: maneuver.position,
            kind: MarkerPlanPointKind.safetyReview,
            label: _safetyLabel(type),
            detail:
                'Do not stop on the live carriageway or slip road. The leader '
                'must choose a legal regrouping or marker position elsewhere.',
          ),
        );
        continue;
      }

      if (type == 'roundabout' || type == 'rotary') {
        if (!rules.markRoundabouts) continue;
        final exit = maneuver.exitNumber;
        final laneCount = maneuver.lanes.length;
        final multiLane = laneCount >= rules.multiLaneRoundaboutThreshold;
        points.add(
          MarkerPlanPoint(
            id: id,
            position: maneuver.position,
            kind: multiLane
                ? MarkerPlanPointKind.safetyReview
                : MarkerPlanPointKind.likelyMarker,
            label: exit == null
                ? 'Roundabout exit marker'
                : 'Roundabout exit $exit marker',
            detail: multiLane
                ? 'Large multi-lane roundabout: inspect a safe, legal position '
                      'after the required exit rather than stopping at entry.'
                : rules.roundaboutEntryAndExit
                ? 'Rules request entry and exit marking; confirm both safe '
                      'positions during the briefing.'
                : 'Default rule: mark the required exit only.',
          ),
        );
        continue;
      }

      final straight = modifier.isEmpty || modifier == 'straight';
      final decisionType = const {'turn', 'fork', 'end of road'}.contains(type);
      if (!decisionType || (straight && !rules.markStraightTurns)) continue;
      points.add(
        MarkerPlanPoint(
          id: id,
          position: maneuver.position,
          kind: MarkerPlanPointKind.likelyMarker,
          label: _decisionLabel(type, modifier),
        ),
      );
    }

    for (final entry in route.waypoints.indexed) {
      final waypoint = entry.$2;
      final searchable = [
        waypoint.name,
        waypoint.description,
        waypoint.symbol,
      ].whereType<String>().join(' ').toLowerCase();
      if (!searchable.contains('muster') &&
          !searchable.contains('regroup') &&
          !searchable.contains('re-group')) {
        continue;
      }
      points.add(
        MarkerPlanPoint(
          id: 'muster-${entry.$1}',
          position: waypoint.point,
          kind: MarkerPlanPointKind.musterPoint,
          label: waypoint.name?.trim().isNotEmpty == true
              ? waypoint.name!.trim()
              : 'Muster point',
          detail: 'Planned regrouping point; not a ride stop or marker role.',
        ),
      );
    }

    return RouteMarkerPlan(points: List.unmodifiable(points));
  }

  static String _safetyLabel(String type) => switch (type) {
    'off ramp' => 'Motorway or dual-carriageway exit review',
    'on ramp' => 'Motorway or dual-carriageway entry review',
    _ => 'Live-lane merge review',
  };

  static String _decisionLabel(String type, String modifier) {
    if (type == 'fork') {
      return modifier.isEmpty ? 'Fork marker' : 'Keep $modifier marker';
    }
    if (type == 'end of road') {
      return modifier.isEmpty
          ? 'End-of-road marker'
          : 'End of road, turn $modifier marker';
    }
    return modifier.isEmpty ? 'Junction marker' : 'Turn $modifier marker';
  }
}
