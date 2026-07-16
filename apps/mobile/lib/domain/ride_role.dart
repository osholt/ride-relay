enum RideRole { lead, rider, tailEndCharlie, marker }

extension RideRoleLabel on RideRole {
  String get label => switch (this) {
    RideRole.lead => 'Lead',
    RideRole.rider => 'Rider',
    RideRole.tailEndCharlie => 'Tail End Charlie',
    RideRole.marker => 'Marker',
  };
}
