import 'package:flutter_test/flutter_test.dart';
import 'package:ride_relay/domain/geo_point.dart';
import 'package:ride_relay/domain/rider_location.dart';
import 'package:ride_relay/domain/route_alert.dart';
import 'package:ride_relay/services/geo_calculations.dart';
import 'package:ride_relay/services/route_deviation_detector.dart';

void main() {
  final route = [
    const GeoPoint(latitude: 51, longitude: -1),
    const GeoPoint(latitude: 51, longitude: -0.99),
  ];

  test('geospatial distance to route is measured against segments', () {
    final distance = GeoCalculations.distanceToPolylineMeters(
      const GeoPoint(latitude: 51.001, longitude: -0.995),
      route,
    );

    expect(distance, closeTo(111.2, 1));
  });

  test('requires repeated outside samples and repeated recovery samples', () {
    final detector = RouteDeviationDetector(
      route,
      config: const RouteDeviationConfig(
        enterOffRouteMeters: 100,
        exitOffRouteMeters: 50,
        samplesToConfirmOffRoute: 3,
        samplesToConfirmRecovery: 2,
      ),
    );
    final start = DateTime.utc(2026, 7, 16, 12);

    expect(
      detector.evaluate(_sample(51.002, start), start).state,
      RouteTrackingState.suspectedOffRoute,
    );
    expect(
      detector
          .evaluate(
            _sample(51.002, start.add(const Duration(seconds: 5))),
            start.add(const Duration(seconds: 5)),
          )
          .state,
      RouteTrackingState.suspectedOffRoute,
    );
    final confirmed = detector.evaluate(
      _sample(51.002, start.add(const Duration(seconds: 10))),
      start.add(const Duration(seconds: 10)),
    );
    expect(confirmed.state, RouteTrackingState.offRoute);
    expect(confirmed.alertLevel, RouteAlertLevel.urgent);
    expect(confirmed.audience, RouteAlertAudience.coordinators);

    expect(
      detector
          .evaluate(
            _sample(51, start.add(const Duration(seconds: 15))),
            start.add(const Duration(seconds: 15)),
          )
          .state,
      RouteTrackingState.recovering,
    );
    expect(
      detector
          .evaluate(
            _sample(51, start.add(const Duration(seconds: 20))),
            start.add(const Duration(seconds: 20)),
          )
          .state,
      RouteTrackingState.onRoute,
    );
  });

  test('stale and inaccurate fixes do not advance off-route hysteresis', () {
    final detector = RouteDeviationDetector(
      route,
      config: const RouteDeviationConfig(
        samplesToConfirmOffRoute: 2,
        staleAfter: Duration(seconds: 20),
        maxAcceptedAccuracyMeters: 50,
      ),
    );
    final now = DateTime.utc(2026, 7, 16, 12);

    final stale = detector.evaluate(
      _sample(51.002, now.subtract(const Duration(seconds: 21))),
      now,
    );
    expect(stale.state, RouteTrackingState.gpsStale);

    final inaccurate = detector.evaluate(
      LocationSample(
        position: const GeoPoint(latitude: 51.002, longitude: -0.995),
        recordedAt: now,
        accuracyMeters: 100,
      ),
      now,
    );
    expect(inaccurate.state, RouteTrackingState.gpsStale);

    final firstValid = detector.evaluate(_sample(51.002, now), now);
    expect(firstValid.state, RouteTrackingState.suspectedOffRoute);
  });

  test('prolonged confirmed deviation escalates to all riders', () {
    final detector = RouteDeviationDetector(
      route,
      config: const RouteDeviationConfig(
        samplesToConfirmOffRoute: 1,
        criticalOffRouteAfter: Duration(minutes: 2),
      ),
    );
    final start = DateTime.utc(2026, 7, 16, 12);
    detector.evaluate(_sample(51.002, start), start);

    final escalated = detector.evaluate(
      _sample(51.002, start.add(const Duration(minutes: 2))),
      start.add(const Duration(minutes: 2)),
    );
    expect(escalated.alertLevel, RouteAlertLevel.critical);
    expect(escalated.audience, RouteAlertAudience.allRiders);
  });

  test('missing route disables deviation alerts', () {
    final assessment = RouteDeviationDetector(
      const [],
    ).evaluate(_sample(51, DateTime.utc(2026)), DateTime.utc(2026));

    expect(assessment.state, RouteTrackingState.unavailable);
    expect(assessment.alertLevel, RouteAlertLevel.none);
  });
}

LocationSample _sample(double latitude, DateTime at) => LocationSample(
  position: GeoPoint(latitude: latitude, longitude: -0.995),
  recordedAt: at,
  accuracyMeters: 5,
);
