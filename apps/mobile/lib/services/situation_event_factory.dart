import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/ride_event.dart';
import '../domain/ride_session.dart';

typedef SituationClock = DateTime Function();
typedef SituationIdFactory = String Function();

class SituationEventFactory {
  const SituationEventFactory({
    required this.session,
    required this.clock,
    required this.idFactory,
  });

  final RideSession session;
  final SituationClock clock;
  final SituationIdFactory idFactory;

  RideEvent create({
    required RideEventType type,
    required Map<String, Object?> payload,
    EventPriority priority = EventPriority.routine,
    DateTime? expiresAt,
  }) {
    final event = RideEvent(
      id: idFactory(),
      rideId: session.rideId,
      deviceId: session.localRiderId,
      type: type,
      priority: priority,
      createdAt: clock(),
      expiresAt: expiresAt,
      payload: payload,
      signature: '',
      schemaVersion: 1,
    );
    return RideEvent(
      id: event.id,
      rideId: event.rideId,
      deviceId: event.deviceId,
      type: event.type,
      priority: event.priority,
      createdAt: event.createdAt,
      expiresAt: event.expiresAt,
      payload: event.payload,
      signature: sign(event, session.inviteSecret),
      schemaVersion: event.schemaVersion,
    );
  }

  static String sign(RideEvent event, String secret) => Hmac(
    sha256,
    utf8.encode(secret),
  ).convert(utf8.encode(_canonicalBody(event))).toString();

  static bool verify(RideEvent event, String secret) {
    final expected = sign(event, secret);
    if (expected.length != event.signature.length) {
      return false;
    }
    var difference = 0;
    for (var index = 0; index < expected.length; index += 1) {
      difference |=
          expected.codeUnitAt(index) ^ event.signature.codeUnitAt(index);
    }
    return difference == 0;
  }

  static String _canonicalBody(RideEvent event) => jsonEncode({
    'schemaVersion': event.schemaVersion,
    'id': event.id,
    'rideId': event.rideId,
    'deviceId': event.deviceId,
    'type': event.type.name,
    'priority': event.priority.name,
    'createdAt': event.createdAt.toUtc().toIso8601String(),
    'expiresAt': event.expiresAt?.toUtc().toIso8601String(),
    'payload': event.payload,
  });
}
