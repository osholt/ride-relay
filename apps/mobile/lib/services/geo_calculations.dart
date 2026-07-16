import 'dart:math' as math;

import '../domain/geo_point.dart';

abstract final class GeoCalculations {
  static const earthRadiusMeters = 6371008.8;

  static double distanceMeters(GeoPoint first, GeoPoint second) {
    final latitude1 = _radians(first.latitude);
    final latitude2 = _radians(second.latitude);
    final latitudeDelta = latitude2 - latitude1;
    final longitudeDelta = _radians(
      _normaliseLongitudeDelta(second.longitude - first.longitude),
    );
    final a =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(latitude1) *
            math.cos(latitude2) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double distanceToPolylineMeters(
    GeoPoint point,
    List<GeoPoint> polyline,
  ) {
    if (polyline.isEmpty) {
      return double.infinity;
    }
    if (polyline.length == 1) {
      return distanceMeters(point, polyline.single);
    }

    var nearest = double.infinity;
    for (var index = 0; index < polyline.length - 1; index += 1) {
      nearest = math.min(
        nearest,
        _distanceToSegmentMeters(point, polyline[index], polyline[index + 1]),
      );
    }
    return nearest;
  }

  static double _distanceToSegmentMeters(
    GeoPoint point,
    GeoPoint start,
    GeoPoint end,
  ) {
    final referenceLatitude = _radians(point.latitude);
    final startX =
        _radians(_normaliseLongitudeDelta(start.longitude - point.longitude)) *
        math.cos(referenceLatitude) *
        earthRadiusMeters;
    final startY =
        _radians(start.latitude - point.latitude) * earthRadiusMeters;
    final endX =
        _radians(_normaliseLongitudeDelta(end.longitude - point.longitude)) *
        math.cos(referenceLatitude) *
        earthRadiusMeters;
    final endY = _radians(end.latitude - point.latitude) * earthRadiusMeters;

    final deltaX = endX - startX;
    final deltaY = endY - startY;
    final lengthSquared = deltaX * deltaX + deltaY * deltaY;
    if (lengthSquared == 0) {
      return math.sqrt(startX * startX + startY * startY);
    }
    final projection = (-(startX * deltaX + startY * deltaY) / lengthSquared)
        .clamp(0.0, 1.0);
    final nearestX = startX + projection * deltaX;
    final nearestY = startY + projection * deltaY;
    return math.sqrt(nearestX * nearestX + nearestY * nearestY);
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  static double _normaliseLongitudeDelta(double delta) =>
      ((delta + 540) % 360) - 180;
}
