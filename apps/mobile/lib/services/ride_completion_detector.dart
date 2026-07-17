import 'dart:math' as math;

import '../domain/geo_point.dart';
import '../domain/rider_location.dart';

/// Conservative, leader-owned completion check for a group ride.
///
/// A ride only ends after every rider with a known position has sent a recent
/// fix inside the destination radius. Stale data therefore keeps the ride open
/// rather than accidentally ending it while somebody has dropped signal.
class RideCompletionDetector {
  const RideCompletionDetector({
    this.destinationRadiusMeters = 90,
    this.locationFreshness = const Duration(minutes: 2),
  });

  final double destinationRadiusMeters;
  final Duration locationFreshness;

  bool everyoneReachedDestination({
    required GeoPoint destination,
    required Iterable<RiderLocation> riderLocations,
    required DateTime now,
  }) {
    final latestByRider = <String, RiderLocation>{
      for (final location in riderLocations) location.riderId: location,
    };
    if (latestByRider.isEmpty) return false;
    return latestByRider.values.every((location) {
      if (location.sample.isStaleAt(now, locationFreshness)) return false;
      return _distanceMeters(location.sample.position, destination) <=
          destinationRadiusMeters;
    });
  }
}

double _distanceMeters(GeoPoint first, GeoPoint second) {
  const earthRadiusMeters = 6371008.8;
  final latitude1 = first.latitude * math.pi / 180;
  final latitude2 = second.latitude * math.pi / 180;
  final latitudeDelta = latitude2 - latitude1;
  final longitudeDelta = (second.longitude - first.longitude) * math.pi / 180;
  final a =
      math.pow(math.sin(latitudeDelta / 2), 2) +
      math.cos(latitude1) *
          math.cos(latitude2) *
          math.pow(math.sin(longitudeDelta / 2), 2);
  return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
