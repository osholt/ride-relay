import '../features/map/motorcycle_icon.dart';
import 'ride_role.dart';
import 'rider_color.dart';

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
    this.motorcycleStyle = motorcycleIconStyleDefault,
    this.riderColor = riderColorDefault,
    this.rideName,
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
  final MotorcycleIconStyle motorcycleStyle;
  final RiderColor riderColor;

  /// Optional, leader-chosen at creation. Never required: rides are always
  /// identifiable by their six-digit code even with no name set.
  final String? rideName;

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
    motorcycleStyle: motorcycleStyle,
    riderColor: riderColor,
    rideName: rideName,
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
    'motorcycleStyle': motorcycleStyle.name,
    'riderColor': riderColor.name,
    if (rideName != null) 'rideName': rideName,
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
    motorcycleStyle: motorcycleIconStyleFromName(
      json['motorcycleStyle'] as String?,
    ),
    riderColor: riderColorFromName(json['riderColor'] as String?),
    rideName: json['rideName'] as String?,
  );

  static int _simulationRiderCount(Object? value) {
    if (value is! int) return defaultSimulationRiderCount;
    return value
        .clamp(minimumSimulationRiderCount, maximumSimulationRiderCount)
        .toInt();
  }
}
