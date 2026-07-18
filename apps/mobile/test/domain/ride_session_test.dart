import 'package:flutter_test/flutter_test.dart';
import 'package:ride_relay/domain/ride_role.dart';
import 'package:ride_relay/domain/ride_session.dart';

void main() {
  final session = RideSession(
    rideId: 'ride',
    rideCode: 'SIM123',
    inviteSecret: 'secret',
    localRiderId: 'lead',
    displayName: 'Demo Lead',
    role: RideRole.lead,
    joinedAt: DateTime.utc(2026, 7, 17),
    isSimulation: true,
  );

  test('simulation marker survives session persistence', () {
    expect(RideSession.fromJson(session.toJson()).isSimulation, isTrue);
  });

  test(
    'simulation rider count persists and legacy sessions use five riders',
    () {
      final configured = RideSession(
        rideId: 'ride',
        rideCode: 'SIM123',
        inviteSecret: 'secret',
        localRiderId: 'lead',
        displayName: 'Demo Lead',
        role: RideRole.lead,
        joinedAt: DateTime.utc(2026, 7, 17),
        isSimulation: true,
        simulationRiderCount: 30,
      );
      expect(
        RideSession.fromJson(configured.toJson()).simulationRiderCount,
        30,
      );

      final legacy = session.toJson()..remove('simulationRiderCount');
      expect(
        RideSession.fromJson(legacy).simulationRiderCount,
        RideSession.defaultSimulationRiderCount,
      );
    },
  );

  test('legacy sessions default to live rides', () {
    final json = session.toJson()..remove('isSimulation');
    expect(RideSession.fromJson(json).isSimulation, isFalse);
  });
}
