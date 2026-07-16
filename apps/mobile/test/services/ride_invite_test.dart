import 'package:flutter_test/flutter_test.dart';
import 'package:ride_relay/services/ride_invite.dart';

void main() {
  test('round-trips an authenticated private invite', () {
    const invite = RideInvite(
      rideId: 'ride-123',
      rideCode: 'ABC234',
      secret: '0123456789abcdef0123456789abcdef',
    );

    final parsed = RideInvite.tryParse('Join my group\n${invite.uri}\n');

    expect(parsed?.rideId, invite.rideId);
    expect(parsed?.rideCode, invite.rideCode);
    expect(parsed?.secret, invite.secret);
  });

  test('rejects incomplete or unbounded invites', () {
    expect(
      RideInvite.tryParse('riderelay://join?code=ABC234&secret=short'),
      isNull,
    );
    expect(
      RideInvite.tryParse(
        'riderelay://join?ride=${'x' * 129}&code=ABC234&secret=${'s' * 16}',
      ),
      isNull,
    );
  });
}
