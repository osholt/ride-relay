import '../domain/distance_unit.dart';

class MeasurementFormatter {
  const MeasurementFormatter(this.unit);

  final DistanceUnit unit;

  String distance(double meters) => switch (unit) {
    DistanceUnit.miles => _imperialDistance(meters),
    DistanceUnit.kilometres => _metricDistance(meters),
  };

  String speed(double metersPerSecond) => switch (unit) {
    DistanceUnit.miles => '${(metersPerSecond * 2.236936).round()} mph',
    DistanceUnit.kilometres => '${(metersPerSecond * 3.6).round()} km/h',
  };

  static String _metricDistance(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';

  static String _imperialDistance(double meters) {
    final miles = meters / 1609.344;
    if (miles < 0.1) return '${(meters * 1.093613).round()} yd';
    return '${miles.toStringAsFixed(1)} mi';
  }
}
