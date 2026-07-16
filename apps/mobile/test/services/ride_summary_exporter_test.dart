import 'package:flutter_test/flutter_test.dart';
import 'package:ride_relay/domain/ride_event.dart';
import 'package:ride_relay/domain/ride_role.dart';
import 'package:ride_relay/domain/ride_session.dart';
import 'package:ride_relay/services/ride_summary_exporter.dart';

void main() {
  test('summarizes complete and active marker sessions deterministically', () {
    final session = RideSession(
      rideId: 'ride-1',
      rideCode: 'ABC123',
      inviteSecret: 'secret',
      localRiderId: 'device-a',
      displayName: 'Oliver',
      role: RideRole.lead,
      joinedAt: DateTime.utc(2026, 7, 16, 9, 55),
    );
    final events = [
      _event('1', RideEventType.rideCreated, 10),
      _event('2', RideEventType.markerStarted, 11),
      _event(
        '3',
        RideEventType.markerPass,
        12,
        payload: const {'riderId': 'rider-1'},
      ),
      _event(
        '4',
        RideEventType.markerPass,
        13,
        payload: const {'riderId': 'rider-1'},
      ),
      _event(
        '5',
        RideEventType.markerEnded,
        16,
        payload: const {'uniquePasses': 3},
      ),
      _event('6', RideEventType.markerStarted, 20),
    ];
    const exporter = RideSummaryExporter();

    final summary = exporter.summarize(
      session,
      events,
      generatedAt: DateTime.utc(2026, 7, 16, 10, 25),
    );

    expect(summary.markerSessions, hasLength(2));
    expect(summary.markerSessions.first.duration, const Duration(minutes: 5));
    expect(summary.markerSessions.first.uniquePassCount, 3);
    expect(summary.markerSessions.first.isComplete, isTrue);
    expect(summary.markerSessions.last.duration, const Duration(minutes: 5));
    expect(summary.markerSessions.last.isComplete, isFalse);
    expect(summary.totalMarkingDuration, const Duration(minutes: 10));
    expect(summary.totalConfirmedPasses, 3);
    expect(
      exporter.toPlainText(summary),
      contains('Time spent marking: 10m 0s'),
    );
    expect(exporter.toCsv(summary), contains('"duration_seconds"'));
    expect(exporter.toCsv(summary), contains('"300","3","true"'));
    expect(exporter.fileName(summary), 'ride-relay-abc123-summary.csv');
  });
}

RideEvent _event(
  String id,
  RideEventType type,
  int minute, {
  Map<String, Object?> payload = const {},
}) => RideEvent(
  id: id,
  rideId: 'ride-1',
  deviceId: 'device-a',
  type: type,
  priority: EventPriority.routine,
  createdAt: DateTime.utc(2026, 7, 16, 10, minute),
  payload: payload,
  signature: 'test',
);
