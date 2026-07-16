import 'package:flutter_test/flutter_test.dart';
import 'package:ride_relay/domain/ride_event.dart';

void main() {
  test('ride events survive JSON round trips', () {
    final event = RideEvent(
      id: 'event-1',
      rideId: 'ride-1',
      deviceId: 'rider-1',
      type: RideEventType.statusMessage,
      priority: EventPriority.critical,
      createdAt: DateTime.utc(2026, 7, 16, 12),
      expiresAt: DateTime.utc(2026, 7, 16, 14),
      payload: const {'message': 'assistance', 'attempt': 1},
      signature: 'signed',
    );

    final decoded = RideEvent.fromJson(event.toJson());

    expect(decoded.id, event.id);
    expect(decoded.type, RideEventType.statusMessage);
    expect(decoded.priority, EventPriority.critical);
    expect(decoded.payload, event.payload);
    expect(decoded.expiresAt?.isAtSameMomentAs(event.expiresAt!), isTrue);
  });
}
