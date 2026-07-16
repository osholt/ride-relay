import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ride_relay/controllers/ride_controller.dart';
import 'package:ride_relay/data/in_memory_event_store.dart';
import 'package:ride_relay/data/in_memory_session_store.dart';
import 'package:ride_relay/domain/quick_message.dart';
import 'package:ride_relay/domain/ride_event.dart';
import 'package:ride_relay/domain/ride_role.dart';
import 'package:ride_relay/services/nearby_bridge.dart';

void main() {
  late InMemoryEventStore eventStore;
  late InMemorySessionStore sessionStore;
  late RideController controller;
  late int id;

  setUp(() async {
    eventStore = InMemoryEventStore();
    sessionStore = InMemorySessionStore();
    id = 0;
    controller = RideController(
      eventStore,
      sessionStore,
      const _FakeNearbyBridge(),
      clock: () => DateTime.utc(2026, 7, 16, 12),
      idFactory: () => 'id-${id++}',
      random: Random(42),
    );
    await controller.initialize();
  });

  tearDown(() => controller.dispose());

  test('new ride is persisted with lead role and a signed event', () async {
    await controller.createRide('Oliver');

    expect(controller.session?.role, RideRole.lead);
    expect(controller.session?.displayName, 'Oliver');
    expect(controller.session?.rideCode, hasLength(6));
    expect(controller.events, hasLength(1));
    expect(controller.events.single.type, RideEventType.rideCreated);
    expect(controller.events.single.signature, hasLength(64));

    final restored = await sessionStore.load();
    expect(restored?.rideId, controller.session?.rideId);
  });

  test('invalid join code is rejected without creating a session', () async {
    await controller.joinRide('123', 'Oliver');

    expect(controller.hasActiveRide, isFalse);
    expect(controller.errorMessage, contains('six-character'));
  });

  test('quick messages are durable, prioritised events', () async {
    await controller.createRide('Oliver');
    await controller.sendQuickMessage(QuickMessage.emergencyStop);

    final pending = await eventStore.pendingEvents(controller.session!.rideId);
    final message = pending.last;
    expect(message.type, RideEventType.statusMessage);
    expect(message.priority, EventPriority.critical);
    expect(message.payload['message'], 'emergencyStop');
  });

  test('marker counts each rider once', () async {
    await controller.createRide('Oliver');
    await controller.startMarker();
    await controller.recordMarkerPass('rider-a');
    await controller.recordMarkerPass('rider-a');
    await controller.recordMarkerPass('rider-b');

    expect(controller.markerPassCount, 2);
    expect(
      controller.events.where(
        (event) => event.type == RideEventType.markerPass,
      ),
      hasLength(2),
    );
  });
}

class _FakeNearbyBridge extends NearbyBridge {
  const _FakeNearbyBridge();

  @override
  Future<NearbyCapabilities> capabilities() async => const NearbyCapabilities(
    platform: 'test',
    nativeBridgeReady: true,
    nearbyApiLinked: false,
    status: 'phase0',
  );
}
