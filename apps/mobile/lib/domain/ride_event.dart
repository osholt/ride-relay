enum RideEventType {
  rideCreated,
  riderJoined,
  roleChanged,
  markerStarted,
  markerPass,
  markerEnded,
  statusMessage,
  rideEnded,
}

enum EventPriority { routine, important, critical }

class RideEvent {
  const RideEvent({
    required this.id,
    required this.rideId,
    required this.deviceId,
    required this.type,
    required this.priority,
    required this.createdAt,
    required this.payload,
    required this.signature,
    this.expiresAt,
    this.acknowledged = false,
    this.schemaVersion = 1,
  });

  final String id;
  final String rideId;
  final String deviceId;
  final RideEventType type;
  final EventPriority priority;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final Map<String, Object?> payload;
  final String signature;
  final bool acknowledged;
  final int schemaVersion;

  RideEvent copyWith({bool? acknowledged}) => RideEvent(
    id: id,
    rideId: rideId,
    deviceId: deviceId,
    type: type,
    priority: priority,
    createdAt: createdAt,
    expiresAt: expiresAt,
    payload: payload,
    signature: signature,
    acknowledged: acknowledged ?? this.acknowledged,
    schemaVersion: schemaVersion,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'rideId': rideId,
    'deviceId': deviceId,
    'type': type.name,
    'priority': priority.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    'payload': payload,
    'signature': signature,
    'acknowledged': acknowledged,
  };

  factory RideEvent.fromJson(Map<String, Object?> json) => RideEvent(
    schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
    id: json['id']! as String,
    rideId: json['rideId']! as String,
    deviceId: json['deviceId']! as String,
    type: RideEventType.values.byName(json['type']! as String),
    priority: EventPriority.values.byName(json['priority']! as String),
    createdAt: DateTime.parse(json['createdAt']! as String).toLocal(),
    expiresAt: switch (json['expiresAt']) {
      final String value => DateTime.parse(value).toLocal(),
      _ => null,
    },
    payload: Map<String, Object?>.from(
      json['payload']! as Map<Object?, Object?>,
    ),
    signature: json['signature']! as String,
    acknowledged: json['acknowledged'] as bool? ?? false,
  );
}
