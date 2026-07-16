import 'dart:math' as math;

import '../domain/geo_point.dart';
import '../domain/rider_location.dart';
import '../domain/route_alert.dart';
import 'geo_calculations.dart';

class RouteDeviationConfig {
  const RouteDeviationConfig({
    this.enterOffRouteMeters = 120,
    this.exitOffRouteMeters = 60,
    this.samplesToConfirmOffRoute = 3,
    this.samplesToConfirmRecovery = 2,
    this.maxAcceptedAccuracyMeters = 75,
    this.staleAfter = const Duration(seconds: 30),
    this.coordinatorStaleAfter = const Duration(seconds: 90),
    this.criticalOffRouteAfter = const Duration(minutes: 3),
  }) : assert(enterOffRouteMeters > exitOffRouteMeters),
       assert(samplesToConfirmOffRoute > 0),
       assert(samplesToConfirmRecovery > 0);

  final double enterOffRouteMeters;
  final double exitOffRouteMeters;
  final int samplesToConfirmOffRoute;
  final int samplesToConfirmRecovery;
  final double maxAcceptedAccuracyMeters;
  final Duration staleAfter;
  final Duration coordinatorStaleAfter;
  final Duration criticalOffRouteAfter;
}

class RouteDeviationDetector {
  RouteDeviationDetector(
    List<GeoPoint> route, {
    this.config = const RouteDeviationConfig(),
  }) : _route = List.unmodifiable(route);

  final List<GeoPoint> _route;
  final RouteDeviationConfig config;

  RouteTrackingState _stableState = RouteTrackingState.onRoute;
  int _outsideSamples = 0;
  int _insideSamples = 0;
  DateTime? _offRouteSince;

  RouteDeviationAssessment evaluate(LocationSample sample, DateTime now) {
    if (_route.length < 2) {
      return RouteDeviationAssessment(
        state: RouteTrackingState.unavailable,
        alertLevel: RouteAlertLevel.none,
        audience: RouteAlertAudience.rider,
        evaluatedAt: now,
        message: 'No route is loaded.',
      );
    }

    final age = sample.ageAt(now);
    if (age > config.staleAfter ||
        sample.accuracyMeters > config.maxAcceptedAccuracyMeters) {
      final coordinatorAlert = age > config.coordinatorStaleAfter;
      return RouteDeviationAssessment(
        state: RouteTrackingState.gpsStale,
        alertLevel: coordinatorAlert
            ? RouteAlertLevel.urgent
            : RouteAlertLevel.watch,
        audience: coordinatorAlert
            ? RouteAlertAudience.coordinators
            : RouteAlertAudience.rider,
        evaluatedAt: now,
        message: sample.accuracyMeters > config.maxAcceptedAccuracyMeters
            ? 'GPS accuracy is too low for route alerts.'
            : 'No recent GPS position is available.',
        offRouteSince: _offRouteSince,
      );
    }

    final distance = GeoCalculations.distanceToPolylineMeters(
      sample.position,
      _route,
    );
    final confidentlyOutside =
        math.max(0, distance - sample.accuracyMeters) >
        config.enterOffRouteMeters;
    final confidentlyInside =
        distance + sample.accuracyMeters < config.exitOffRouteMeters;

    if (_stableState == RouteTrackingState.offRoute) {
      if (confidentlyInside) {
        _insideSamples += 1;
        if (_insideSamples >= config.samplesToConfirmRecovery) {
          _stableState = RouteTrackingState.onRoute;
          _insideSamples = 0;
          _outsideSamples = 0;
          _offRouteSince = null;
          return _assessment(
            state: RouteTrackingState.onRoute,
            now: now,
            distance: distance,
            message: 'Back on route.',
          );
        }
        return _assessment(
          state: RouteTrackingState.recovering,
          now: now,
          distance: distance,
          message: 'Route recovery is being confirmed.',
        );
      }
      _insideSamples = 0;
      return _offRouteAssessment(now, distance);
    }

    if (confidentlyOutside) {
      _outsideSamples += 1;
      if (_outsideSamples >= config.samplesToConfirmOffRoute) {
        _stableState = RouteTrackingState.offRoute;
        _offRouteSince ??= now;
        _insideSamples = 0;
        return _offRouteAssessment(now, distance);
      }
      return _assessment(
        state: RouteTrackingState.suspectedOffRoute,
        now: now,
        distance: distance,
        message: 'Possible route deviation; waiting for another GPS sample.',
      );
    }

    _outsideSamples = 0;
    return _assessment(
      state: RouteTrackingState.onRoute,
      now: now,
      distance: distance,
      message: 'On route.',
    );
  }

  RouteDeviationAssessment _offRouteAssessment(DateTime now, double distance) {
    final since = _offRouteSince ?? now;
    final critical = now.difference(since) >= config.criticalOffRouteAfter;
    return RouteDeviationAssessment(
      state: RouteTrackingState.offRoute,
      alertLevel: critical ? RouteAlertLevel.critical : RouteAlertLevel.urgent,
      audience: critical
          ? RouteAlertAudience.allRiders
          : RouteAlertAudience.coordinators,
      evaluatedAt: now,
      message: critical
          ? 'Rider remains off route; immediate follow-up required.'
          : 'Rider is confirmed off route. Lead and TEC should check in.',
      distanceFromRouteMeters: distance,
      offRouteSince: since,
    );
  }

  RouteDeviationAssessment _assessment({
    required RouteTrackingState state,
    required DateTime now,
    required double distance,
    required String message,
  }) => RouteDeviationAssessment(
    state: state,
    alertLevel:
        state == RouteTrackingState.suspectedOffRoute ||
            state == RouteTrackingState.recovering
        ? RouteAlertLevel.watch
        : RouteAlertLevel.none,
    audience: RouteAlertAudience.rider,
    evaluatedAt: now,
    message: message,
    distanceFromRouteMeters: distance,
    offRouteSince: _offRouteSince,
  );
}
