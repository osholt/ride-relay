import 'ride_role.dart';

class RideSession {
  static const minimumSimulationRiderCount = 4;
  static const maximumSimulationRiderCount = 30;
  static const defaultSimulationRiderCount = 5;

  const RideSession({
    required this.rideId,
    required this.rideCode,
    required this.inviteSecret,
    required this.localRiderId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    this.isSimulation = false,
    this.simulationRiderCount = defaultSimulationRiderCount,
  }) : assert(
         !isSimulation ||
             (simulationRiderCount >= minimumSimulationRiderCount &&
                 simulationRiderCount <= maximumSimulationRiderCount),
       );

  final String rideId;
  final String rideCode;
  final String inviteSecret;
  final String localRiderId;
  final String displayName;
  final RideRole role;
  final DateTime joinedAt;
  final bool isSimulation;
  final int simulationRiderCount;

  RideSession copyWith({
    RideRole? role,
    String? rideCode,
    int? simulationRiderCount,
  }) => RideSession(
    rideId: rideId,
    rideCode: rideCode ?? this.rideCode,
    inviteSecret: inviteSecret,
    localRiderId: localRiderId,
    displayName: displayName,
    role: role ?? this.role,
    joinedAt: joinedAt,
    isSimulation: isSimulation,
    simulationRiderCount: simulationRiderCount ?? this.simulationRiderCount,
  );

  Map<String, Object?> toJson() => {
    'rideId': rideId,
    'rideCode': rideCode,
    'inviteSecret': inviteSecret,
    'localRiderId': localRiderId,
    'displayName': displayName,
    'role': role.name,
    'joinedAt': joinedAt.toUtc().toIso8601String(),
    if (isSimulation) 'isSimulation': true,
    if (isSimulation) 'simulationRiderCount': simulationRiderCount,
  };

  factory RideSession.fromJson(Map<String, Object?> json) => RideSession(
    rideId: json['rideId']! as String,
    rideCode: json['rideCode']! as String,
    inviteSecret: json['inviteSecret']! as String,
    localRiderId: json['localRiderId']! as String,
    displayName: json['displayName']! as String,
    role: RideRole.values.byName(json['role']! as String),
    joinedAt: DateTime.parse(json['joinedAt']! as String).toLocal(),
    isSimulation: json['isSimulation'] as bool? ?? false,
    simulationRiderCount: _simulationRiderCount(json['simulationRiderCount']),
  );

  static int _simulationRiderCount(Object? value) {
    if (value is! int) return defaultSimulationRiderCount;
    return value
        .clamp(minimumSimulationRiderCount, maximumSimulationRiderCount)
        .toInt();
  }
}
