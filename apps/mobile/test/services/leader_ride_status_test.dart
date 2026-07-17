import 'package:flutter_test/flutter_test.dart';
import 'package:ride_relay/domain/geo_point.dart';
import 'package:ride_relay/domain/ride_role.dart';
import 'package:ride_relay/domain/rider_location.dart';
import 'package:ride_relay/domain/route_alert.dart';
import 'package:ride_relay/services/leader_ride_status.dart';

void main() {
  final now = DateTime.utc(2026, 7, 17, 10);

  test('leader receives along-route TEC distance and estimated time gap', () {
    final status = const LeaderRideStatusCalculator().calculate(
      localRole: RideRole.lead,
      localRiderId: 'lead',
      localLocation: _location(
        id: 'lead',
        name: 'Lead',
        role: RideRole.lead,
        longitude: 0.015,
        speed: 10,
        at: now,
      ),
      riderLocations: [
        _location(
          id: 'tec',
          name: 'Charlie',
          role: RideRole.tailEndCharlie,
          longitude: 0.005,
          speed: 10,
          at: now,
        ),
      ],
      routeAlerts: const [],
      route: const [
        GeoPoint(latitude: 0, longitude: 0),
        GeoPoint(latitude: 0, longitude: 0.02),
      ],
      now: now,
    );

    expect(status, isNotNull);
    expect(status!.tecName, 'Charlie');
    expect(status.distanceToTecMeters, closeTo(1112, 10));
    expect(status.estimatedTimeToTec!.inSeconds, inInclusiveRange(105, 115));
  });

  test('leader receives simple unacknowledged off-course alerts', () {
    final status = const LeaderRideStatusCalculator().calculate(
      localRole: RideRole.lead,
      localRiderId: 'lead',
      localLocation: null,
      riderLocations: const [],
      routeAlerts: [
        RiderRouteAlert(
          riderId: 'rider',
          displayName: 'Alex',
          assessment: RouteDeviationAssessment(
            state: RouteTrackingState.offRoute,
            alertLevel: RouteAlertLevel.urgent,
            audience: RouteAlertAudience.coordinators,
            evaluatedAt: now,
            message: 'Off route',
            distanceFromRouteMeters: 240,
          ),
        ),
      ],
      route: const [],
      now: now,
    );

    expect(status!.offCourseAlerts.single.displayName, 'Alex');
    expect(status.offCourseAlerts.single.distanceFromRouteMeters, 240);
  });

  test('non-leaders do not receive leader map status', () {
    final status = const LeaderRideStatusCalculator().calculate(
      localRole: RideRole.rider,
      localRiderId: 'rider',
      localLocation: null,
      riderLocations: const [],
      routeAlerts: const [],
      route: const [],
      now: now,
    );

    expect(status, isNull);
  });
}

RiderLocation _location({
  required String id,
  required String name,
  required RideRole role,
  required double longitude,
  required double speed,
  required DateTime at,
}) => RiderLocation(
  riderId: id,
  displayName: name,
  role: role,
  sample: LocationSample(
    position: GeoPoint(latitude: 0, longitude: longitude),
    recordedAt: at,
    accuracyMeters: 5,
    speedMetersPerSecond: speed,
  ),
  receivedAt: at,
);
