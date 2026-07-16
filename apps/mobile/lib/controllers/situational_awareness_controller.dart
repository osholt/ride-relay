import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../domain/event_store.dart';
import '../domain/geo_point.dart';
import '../domain/hazard.dart';
import '../domain/ride_event.dart';
import '../domain/ride_session.dart';
import '../domain/rider_location.dart';
import '../domain/route_alert.dart';
import '../services/external_hazard_provider.dart';
import '../services/hazard_deduplicator.dart';
import '../services/route_deviation_detector.dart';
import '../services/situation_event_factory.dart';

class SituationalAwarenessController extends ChangeNotifier {
  SituationalAwarenessController(
    this._eventStore,
    this._session, {
    required List<GeoPoint> route,
    List<ExternalHazardProvider> externalProviders = const [],
    SituationClock? clock,
    SituationIdFactory? idFactory,
    this.expiryPolicy = const HazardExpiryPolicy(),
    this.deduplicator = const HazardDeduplicator(),
    this.routeConfig = const RouteDeviationConfig(),
  }) : _route = List.unmodifiable(route),
       _externalProviders = List.unmodifiable(externalProviders),
       _clock = clock ?? DateTime.now,
       _idFactory = idFactory ?? const Uuid().v7 {
    _eventFactory = SituationEventFactory(
      session: _session,
      clock: _clock,
      idFactory: _idFactory,
    );
  }

  final EventStore _eventStore;
  final RideSession _session;
  final List<GeoPoint> _route;
  final List<ExternalHazardProvider> _externalProviders;
  final SituationClock _clock;
  final SituationIdFactory _idFactory;
  final HazardExpiryPolicy expiryPolicy;
  final HazardDeduplicator deduplicator;
  final RouteDeviationConfig routeConfig;
  late final SituationEventFactory _eventFactory;

  final Map<String, RiderLocation> _locations = {};
  final Map<String, HazardReport> _hazards = {};
  final Map<String, RiderRouteAlert> _alerts = {};
  final Map<String, RouteDeviationDetector> _detectors = {};
  bool _busy = false;
  String? _errorMessage;

  bool get busy => _busy;
  String? get errorMessage => _errorMessage;
  List<GeoPoint> get route => _route;

  List<RiderLocation> get riderLocations {
    final values = _locations.values.toList(growable: false);
    values.sort(
      (first, second) => first.displayName.compareTo(second.displayName),
    );
    return List.unmodifiable(values);
  }

  List<HazardReport> get activeHazards {
    final now = _clock();
    final values = _hazards.values
        .where((hazard) => hazard.isActiveAt(now))
        .toList();
    values.sort((first, second) {
      final bySeverity = second.severity.index.compareTo(first.severity.index);
      return bySeverity != 0
          ? bySeverity
          : second.updatedAt.compareTo(first.updatedAt);
    });
    return List.unmodifiable(values);
  }

  List<RiderRouteAlert> get routeAlerts {
    final values = _alerts.values
        .where((alert) => alert.assessment.alertLevel != RouteAlertLevel.none)
        .toList();
    values.sort(
      (first, second) => second.assessment.alertLevel.index.compareTo(
        first.assessment.alertLevel.index,
      ),
    );
    return List.unmodifiable(values);
  }

  List<ExternalHazardProvider> get externalProviders => _externalProviders;

  RiderLocation? get localLocation => _locations[_session.localRiderId];

  RiderRouteAlert? alertFor(String riderId) => _alerts[riderId];

  Future<void> initialize() async {
    final events = await _eventStore.eventsForRide(_session.rideId);
    for (final event in events) {
      _applyEvent(event, replaying: true);
    }
    _removeExpiredHazards();
    notifyListeners();
  }

  Future<void> recordLocalLocation(LocationSample sample) async {
    final location = RiderLocation(
      riderId: _session.localRiderId,
      displayName: _session.displayName,
      role: _session.role,
      sample: sample,
      receivedAt: _clock(),
    );
    await _run(() async {
      final previousAlert = _alerts[location.riderId]?.assessment;
      final event = _eventFactory.create(
        type: RideEventType.riderLocationUpdated,
        payload: {'location': location.toJson()},
        expiresAt: _clock().add(const Duration(minutes: 30)),
      );
      await _appendAndApply(event);
      final currentAlert = _alerts[location.riderId]?.assessment;
      if (previousAlert?.state != currentAlert?.state ||
          previousAlert?.alertLevel != currentAlert?.alertLevel ||
          previousAlert?.audience != currentAlert?.audience) {
        await _persistAlertTransition(location.riderId);
      }
    });
  }

  Future<HazardReport?> reportHazard({
    required HazardType type,
    required HazardSeverity severity,
    GeoPoint? position,
    String? details,
  }) async {
    HazardReport? result;
    await _run(() async {
      final reportPosition = position ?? localLocation?.sample.position;
      if (reportPosition == null) {
        throw const FormatException(
          'A current location is required to report a hazard.',
        );
      }
      final now = _clock();
      final trimmedDetails = details?.trim();
      final incoming = HazardReport(
        id: _idFactory(),
        rideId: _session.rideId,
        type: type,
        severity: severity,
        position: reportPosition,
        reportedAt: now,
        updatedAt: now,
        expiresAt: now.add(expiryPolicy.durationFor(type, severity)),
        reporterId: _session.localRiderId,
        reporterName: _session.displayName,
        source: HazardSource.rider,
        details: trimmedDetails == null || trimmedDetails.isEmpty
            ? null
            : trimmedDetails.substring(
                0,
                trimmedDetails.length > 160 ? 160 : trimmedDetails.length,
              ),
      );
      result = deduplicator.mergeOrAdd(incoming, activeHazards);
      final event = _eventFactory.create(
        type: RideEventType.hazardReported,
        payload: {'hazard': result!.toJson()},
        priority: _priorityForSeverity(result!.severity),
        expiresAt: result!.expiresAt,
      );
      await _appendAndApply(event);
    });
    return result;
  }

  Future<void> clearHazard(String hazardId, {String reason = 'cleared'}) async {
    if (!_hazards.containsKey(hazardId)) {
      return;
    }
    await _run(() async {
      final event = _eventFactory.create(
        type: RideEventType.hazardCleared,
        payload: {'hazardId': hazardId, 'reason': reason},
        priority: EventPriority.important,
      );
      await _appendAndApply(event);
    });
  }

  Future<void> acknowledgeAlert(String riderId) async {
    final alert = _alerts[riderId];
    if (alert == null || alert.acknowledged) {
      return;
    }
    await _run(() async {
      final acknowledgedAt = _clock();
      final updated = alert.copyWithAcknowledgement(
        acknowledgedBy: _session.localRiderId,
        acknowledgedAt: acknowledgedAt,
      );
      final event = _eventFactory.create(
        type: RideEventType.routeAlertAcknowledged,
        payload: {'alert': updated.toJson()},
        priority: EventPriority.important,
      );
      await _appendAndApply(event);
    });
  }

  Future<void> ingestRemoteEvent(RideEvent event) async {
    if (event.rideId != _session.rideId ||
        !_supportedSituationalEventTypes.contains(event.type)) {
      throw const FormatException('Event is not valid for this ride.');
    }
    if (!SituationEventFactory.verify(event, _session.inviteSecret)) {
      throw const FormatException('Event signature is invalid.');
    }
    await _eventStore.append(event);
    _applyEvent(event);
    notifyListeners();
  }

  Future<void> refreshExternalHazards() async {
    if (_route.isEmpty) {
      return;
    }
    await _run(() async {
      for (final provider in _externalProviders) {
        if (!provider.status.canFetch) {
          continue;
        }
        final result = await provider.fetch(
          ExternalHazardQuery(
            rideId: _session.rideId,
            route: _route,
            requestedAt: _clock(),
          ),
        );
        for (final hazard in result.hazards) {
          if (hazard.source != HazardSource.externalProvider ||
              hazard.providerId != provider.id ||
              hazard.rideId != _session.rideId) {
            continue;
          }
          final merged = deduplicator.mergeOrAdd(hazard, activeHazards);
          final event = _eventFactory.create(
            type: RideEventType.hazardReported,
            payload: {'hazard': merged.toJson()},
            priority: _priorityForSeverity(merged.severity),
            expiresAt: merged.expiresAt,
          );
          await _appendAndApply(event);
        }
      }
    });
  }

  void refreshStaleness() {
    _removeExpiredHazards();
    for (final location in _locations.values) {
      _evaluateLocation(location);
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _persistAlertTransition(String riderId) async {
    final alert = _alerts[riderId];
    if (alert == null) {
      return;
    }
    final event = _eventFactory.create(
      type: RideEventType.routeDeviationChanged,
      payload: {'alert': alert.toJson()},
      priority: _priorityForAlert(alert.assessment.alertLevel),
      expiresAt: _clock().add(const Duration(hours: 2)),
    );
    await _eventStore.append(event);
  }

  Future<void> _appendAndApply(RideEvent event) async {
    await _eventStore.append(event);
    _applyEvent(event);
  }

  void _applyEvent(RideEvent event, {bool replaying = false}) {
    if (event.rideId != _session.rideId) {
      return;
    }
    switch (event.type) {
      case RideEventType.riderLocationUpdated:
        final location = RiderLocation.fromJson(
          _mapPayload(event.payload['location']),
        );
        final previous = _locations[location.riderId];
        if (previous == null ||
            !location.sample.recordedAt.isBefore(previous.sample.recordedAt)) {
          _locations[location.riderId] = location;
          _evaluateLocation(location);
        }
        break;
      case RideEventType.hazardReported:
        final hazard = HazardReport.fromJson(
          _mapPayload(event.payload['hazard']),
        );
        if (hazard.rideId == _session.rideId && hazard.isActiveAt(_clock())) {
          _hazards[hazard.id] = hazard;
        }
        break;
      case RideEventType.hazardCleared:
        _hazards.remove(event.payload['hazardId']);
        break;
      case RideEventType.routeDeviationChanged:
      case RideEventType.routeAlertAcknowledged:
        final alert = RiderRouteAlert.fromJson(
          _mapPayload(event.payload['alert']),
        );
        final current = _alerts[alert.riderId];
        if (current == null ||
            !alert.assessment.evaluatedAt.isBefore(
              current.assessment.evaluatedAt,
            )) {
          _alerts[alert.riderId] = alert;
        }
        break;
      case RideEventType.rideCreated:
      case RideEventType.riderJoined:
      case RideEventType.roleChanged:
      case RideEventType.markerStarted:
      case RideEventType.markerPass:
      case RideEventType.markerEnded:
      case RideEventType.statusMessage:
      case RideEventType.rideEnded:
        break;
    }
    if (!replaying) {
      _removeExpiredHazards();
    }
  }

  void _evaluateLocation(RiderLocation location) {
    final detector = _detectors.putIfAbsent(
      location.riderId,
      () => RouteDeviationDetector(_route, config: routeConfig),
    );
    final assessment = detector.evaluate(location.sample, _clock());
    final previous = _alerts[location.riderId];
    if (previous?.assessment.state != assessment.state ||
        previous?.assessment.alertLevel != assessment.alertLevel ||
        previous?.assessment.audience != assessment.audience) {
      _alerts[location.riderId] = RiderRouteAlert(
        riderId: location.riderId,
        displayName: location.displayName,
        assessment: assessment,
      );
    }
  }

  void _removeExpiredHazards() {
    final now = _clock();
    _hazards.removeWhere((_, hazard) => !hazard.isActiveAt(now));
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) {
      return;
    }
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await operation();
    } on FormatException catch (error) {
      _errorMessage = error.message;
    } on Object catch (error, stackTrace) {
      _errorMessage = 'Situational awareness could not be updated.';
      debugPrint('Situational awareness failed: $error\n$stackTrace');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  static Map<String, Object?> _mapPayload(Object? value) =>
      Map<String, Object?>.from(value! as Map);

  static EventPriority _priorityForSeverity(HazardSeverity severity) =>
      switch (severity) {
        HazardSeverity.advisory => EventPriority.routine,
        HazardSeverity.caution ||
        HazardSeverity.serious => EventPriority.important,
        HazardSeverity.critical => EventPriority.critical,
      };

  static EventPriority _priorityForAlert(RouteAlertLevel level) =>
      switch (level) {
        RouteAlertLevel.none || RouteAlertLevel.watch => EventPriority.routine,
        RouteAlertLevel.urgent => EventPriority.important,
        RouteAlertLevel.critical => EventPriority.critical,
      };

  static const _supportedSituationalEventTypes = {
    RideEventType.riderLocationUpdated,
    RideEventType.hazardReported,
    RideEventType.hazardCleared,
    RideEventType.routeDeviationChanged,
    RideEventType.routeAlertAcknowledged,
  };
}
