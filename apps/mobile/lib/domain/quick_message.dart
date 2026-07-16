import 'ride_event.dart';

enum QuickMessage {
  stopped,
  mechanical,
  fuel,
  assistance,
  routeBlocked,
  emergencyStop,
  allPassed,
  resolved,
}

extension QuickMessageDetails on QuickMessage {
  String get label => switch (this) {
    QuickMessage.stopped => 'Stopped',
    QuickMessage.mechanical => 'Mechanical',
    QuickMessage.fuel => 'Need fuel',
    QuickMessage.assistance => 'Need help',
    QuickMessage.routeBlocked => 'Route blocked',
    QuickMessage.emergencyStop => 'Emergency stop',
    QuickMessage.allPassed => 'All riders passed',
    QuickMessage.resolved => 'Resolved',
  };

  EventPriority get priority => switch (this) {
    QuickMessage.emergencyStop ||
    QuickMessage.assistance => EventPriority.critical,
    QuickMessage.mechanical ||
    QuickMessage.routeBlocked => EventPriority.important,
    _ => EventPriority.routine,
  };
}
