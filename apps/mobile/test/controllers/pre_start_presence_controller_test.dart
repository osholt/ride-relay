import 'package:flutter_test/flutter_test.dart';
import 'package:ride_relay/controllers/pre_start_presence_controller.dart';
import 'package:ride_relay/domain/geo_point.dart';
import 'package:ride_relay/domain/ride_role.dart';
import 'package:ride_relay/domain/ride_session.dart';
import 'package:ride_relay/domain/rider_location.dart';
import 'package:ride_relay/internet/internet_relay_client.dart';

void main() {
  final session = RideSession(
    rideId: 'ride-presence',
    rideCode: '123456',
    inviteSecret: '0123456789abcdef0123456789abcdef',
    joinToken: 'test-join-token-0123456789',
    localRiderId: 'local',
    displayName: 'Oliver',
    role: RideRole.lead,
    joinedAt: DateTime.utc(2026, 7, 23, 10),
  );

  test(
    'keeps only fresh latest positions and clears without a journal',
    () async {
      var now = DateTime.utc(2026, 7, 23, 10);
      final remote = _location(
        riderId: 'remote',
        displayName: 'Alex',
        latitude: 51.1,
        receivedAt: now,
      );
      final api = _FakePresenceApi([
        PreStartPresenceResult(
          locations: [remote],
          ttl: const Duration(seconds: 45),
        ),
        PreStartPresenceResult(
          locations: [remote],
          ttl: const Duration(seconds: 45),
        ),
        const PreStartPresenceResult(locations: [], ttl: Duration(seconds: 45)),
      ]);
      final controller = PreStartPresenceController(
        api,
        pollInterval: const Duration(days: 1),
        clock: () => now,
      );
      addTearDown(controller.close);

      await controller.start(session);
      expect(controller.locations.single.riderId, 'remote');

      final local = _location(
        riderId: 'local',
        displayName: 'Oliver',
        latitude: 51.2,
        receivedAt: now,
      );
      controller.updateLocalPosition(local);
      await Future<void>.delayed(Duration.zero);

      expect(api.calls.last.position?.sample.position.latitude, 51.2);
      expect(api.calls.last.clear, isFalse);

      now = now.add(const Duration(seconds: 46));
      expect(controller.locations, isEmpty);

      await controller.clearLocalPosition();
      expect(api.calls.last.position, isNull);
      expect(api.calls.last.clear, isTrue);
    },
  );
}

RiderLocation _location({
  required String riderId,
  required String displayName,
  required double latitude,
  required DateTime receivedAt,
}) => RiderLocation(
  riderId: riderId,
  displayName: displayName,
  role: riderId == 'local' ? RideRole.lead : RideRole.rider,
  sample: LocationSample(
    position: GeoPoint(latitude: latitude, longitude: -2.4),
    recordedAt: receivedAt,
    accuracyMeters: 4,
  ),
  receivedAt: receivedAt,
);

class _FakePresenceApi implements PreStartPresenceApi {
  _FakePresenceApi(this._results);

  final List<PreStartPresenceResult> _results;
  final List<({RideSession session, RiderLocation? position, bool clear})>
  calls = [];

  @override
  InternetRelayConfiguration get configuration =>
      InternetRelayConfiguration(baseUri: Uri.parse('https://relay.example'));

  @override
  Future<PreStartPresenceResult> synchronizePreStartPresence({
    required RideSession session,
    required RiderLocation? position,
    required bool clear,
  }) async {
    calls.add((session: session, position: position, clear: clear));
    return _results.removeAt(0);
  }

  @override
  void close() {}
}
