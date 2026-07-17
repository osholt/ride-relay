import 'package:flutter_test/flutter_test.dart';
import 'package:ride_relay/domain/distance_unit.dart';
import 'package:ride_relay/services/measurement_formatter.dart';

void main() {
  test('formats metric and imperial distance and speed', () {
    const metric = MeasurementFormatter(DistanceUnit.kilometres);
    const imperial = MeasurementFormatter(DistanceUnit.miles);

    expect(metric.distance(3200), '3.2 km');
    expect(metric.speed(10), '36 km/h');
    expect(imperial.distance(3218.688), '2.0 mi');
    expect(imperial.speed(10), '22 mph');
    expect(imperial.distance(50), '55 yd');
  });
}
