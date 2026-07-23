import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/rider_location.dart';
import '../domain/ride_session.dart';
import '../internet/internet_relay_client.dart';

/// Maintains one short-lived, non-journalled position per rider before start.
///
/// This controller deliberately has no [EventStore] dependency. Its snapshots
/// disappear when stale, when the controller stops, or when the process exits.
class PreStartPresenceController extends ChangeNotifier {
  PreStartPresenceController(
    this._api, {
    this.pollInterval = const Duration(seconds: 4),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PreStartPresenceApi _api;
  final Duration pollInterval;
  final DateTime Function() _clock;
  RideSession? _session;
  RiderLocation? _localPosition;
  List<RiderLocation> _locations = const [];
  Duration _ttl = const Duration(seconds: 45);
  Timer? _timer;
  bool _active = false;
  bool _syncing = false;
  bool _closed = false;
  bool _clearOnNextSync = false;
  String? _statusMessage;

  bool get active => _active;
  bool get supported => _statusMessage != 'feature_unsupported';
  String? get statusMessage => _statusMessage;
  List<RiderLocation> get locations {
    final now = _clock();
    return List.unmodifiable(
      _locations.where(
        (location) => now.difference(location.receivedAt) <= _ttl,
      ),
    );
  }

  Future<void> start(RideSession session) async {
    if (_closed) throw StateError('Pre-start presence controller is closed.');
    _session = session;
    _active = true;
    _statusMessage = null;
    await synchronizeNow();
  }

  void updateLocalPosition(RiderLocation location) {
    final session = _session;
    if (!_active ||
        session == null ||
        location.riderId != session.localRiderId) {
      return;
    }
    _localPosition = location;
    _locations = [
      ..._locations.where((value) => value.riderId != location.riderId),
      location,
    ];
    notifyListeners();
    wake();
  }

  Future<void> clearLocalPosition() async {
    final localId = _session?.localRiderId;
    _localPosition = null;
    if (localId != null) {
      _locations = _locations
          .where((location) => location.riderId != localId)
          .toList(growable: false);
    }
    _clearOnNextSync = true;
    notifyListeners();
    await synchronizeNow();
  }

  Future<void> synchronizeNow() async {
    final session = _session;
    if (!_active || _closed || _syncing || session == null) return;
    _timer?.cancel();
    _timer = null;
    _syncing = true;
    try {
      final result = await _api.synchronizePreStartPresence(
        session: session,
        position: _clearOnNextSync ? null : _localPosition,
        clear: _clearOnNextSync,
      );
      if (!_active || _closed || !identical(session, _session)) return;
      _clearOnNextSync = false;
      _ttl = result.ttl;
      _locations = result.locations;
      _statusMessage = null;
      notifyListeners();
    } on InternetRelayException catch (error) {
      if (!_active || _closed || !identical(session, _session)) return;
      _statusMessage = error.code ?? error.message;
      notifyListeners();
    } finally {
      _syncing = false;
      if (_active && !_closed) {
        _timer = Timer(pollInterval, () => unawaited(synchronizeNow()));
      }
    }
  }

  void wake() {
    if (!_active || _closed || _syncing || _timer == null) return;
    _timer?.cancel();
    _timer = null;
    unawaited(synchronizeNow());
  }

  Future<void> stop({bool clearRemote = true}) async {
    if (!_active) {
      _locations = const [];
      return;
    }
    _timer?.cancel();
    _timer = null;
    final session = _session;
    _active = false;
    _locations = const [];
    notifyListeners();
    if (clearRemote && session != null) {
      try {
        await _api.synchronizePreStartPresence(
          session: session,
          position: null,
          clear: true,
        );
      } on Object {
        // The server TTL remains the bounded cleanup fallback.
      }
    }
    _localPosition = null;
    _clearOnNextSync = false;
  }

  Future<void> close() async {
    if (_closed) return;
    await stop();
    _closed = true;
    _session = null;
    _api.close();
    dispose();
  }
}
