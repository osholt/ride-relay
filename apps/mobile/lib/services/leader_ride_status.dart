import '../domain/geo_point.dart';
import '../domain/ride_role.dart';
import '../domain/rider_location.dart';
import '../domain/route_alert.dart';
import 'geo_calculations.dart';

class LeaderOffCourseAlert {
  const LeaderOffCourseAlert({
    required this.riderId,
    required this.displayName,
    required this.level,
    this.distanceFromRouteMeters,
  });

  final String riderId;
  final String displayName;
  final RouteAlertLevel level;
  final double? distanceFromRouteMeters;
}

class LeaderRideStatus {
  const LeaderRideStatus({
    required this.offCourseAlerts,
    this.tecName,
    this.distanceToTecMeters,
    this.estimatedTimeToTec,
    this.tecLocationAge,
  });

  final String? tecName;
  final double? distanceToTecMeters;
  final Duration? estimatedTimeToTec;
  final Duration? tecLocationAge;
  final List<LeaderOffCourseAlert> offCourseAlerts;
}

class LeaderRideStatusCalculator {
  const LeaderRideStatusCalculator({
    this.defaultMovingSpeedMetersPerSecond = 13.4,
    this.maximumOnRouteDistanceMeters = 250,
    this.staleAfter = const Duration(minutes: 2),
  });

  final double defaultMovingSpeedMetersPerSecond;
  final double maximumOnRouteDistanceMeters;
  final Duration staleAfter;

  LeaderRideStatus? calculate({
    required RideRole localRole,
    required String localRiderId,
    required RiderLocation? localLocation,
    required List<RiderLocation> riderLocations,
    required List<RiderRouteAlert> routeAlerts,
    required List<GeoPoint> route,
    DateTime? now,
  }) {
    if (localRole != RideRole.lead) return null;
    final evaluatedAt = now ?? DateTime.now();
    final offCourseAlerts = routeAlerts
        .where(
          (alert) =>
              alert.riderId != localRiderId &&
              !alert.acknowledged &&
              alert.assessment.coordinatorActionRequired,
        )
        .map(
          (alert) => LeaderOffCourseAlert(
            riderId: alert.riderId,
            displayName: alert.displayName,
            level: alert.assessment.alertLevel,
            distanceFromRouteMeters: alert.assessment.distanceFromRouteMeters,
          ),
        )
        .toList(growable: false);

    final tecCandidates =
        riderLocations
            .where(
              (location) =>
                  location.riderId != localRiderId &&
                  location.role == RideRole.tailEndCharlie,
            )
            .toList(growable: false)
          ..sort(
            (first, second) =>
                second.sample.recordedAt.compareTo(first.sample.recordedAt),
          );
    final tec = tecCandidates.firstOrNull;
    if (tec == null) {
      return LeaderRideStatus(offCourseAlerts: offCourseAlerts);
    }

    final age = tec.sample.ageAt(evaluatedAt);
    if (localLocation == null || age > staleAfter) {
      return LeaderRideStatus(
        tecName: tec.displayName,
        tecLocationAge: age,
        offCourseAlerts: offCourseAlerts,
      );
    }

    final distance = _distanceBetween(localLocation, tec, route);
    final movingSpeeds = [
      localLocation.sample.speedMetersPerSecond,
      tec.sample.speedMetersPerSecond,
    ].whereType<double>().where((speed) => speed >= 2).toList(growable: false);
    final speed = movingSpeeds.isEmpty
        ? defaultMovingSpeedMetersPerSecond
        : movingSpeeds.reduce((a, b) => a + b) / movingSpeeds.length;
    final seconds = distance < 25 ? 0 : (distance / speed).round();
    return LeaderRideStatus(
      tecName: tec.displayName,
      distanceToTecMeters: distance,
      estimatedTimeToTec: Duration(seconds: seconds),
      tecLocationAge: age,
      offCourseAlerts: offCourseAlerts,
    );
  }

  double _distanceBetween(
    RiderLocation lead,
    RiderLocation tec,
    List<GeoPoint> route,
  ) {
    if (route.length >= 2) {
      final leadProjection = GeoCalculations.projectOntoPolyline(
        lead.sample.position,
        route,
      );
      final tecProjection = GeoCalculations.projectOntoPolyline(
        tec.sample.position,
        route,
      );
      if (leadProjection.distanceFromRouteMeters <=
              maximumOnRouteDistanceMeters &&
          tecProjection.distanceFromRouteMeters <=
              maximumOnRouteDistanceMeters) {
        return (leadProjection.distanceAlongRouteMeters -
                tecProjection.distanceAlongRouteMeters)
            .abs();
      }
    }
    return GeoCalculations.distanceMeters(
      lead.sample.position,
      tec.sample.position,
    );
  }
}
