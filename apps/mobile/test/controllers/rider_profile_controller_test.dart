import 'package:flutter_test/flutter_test.dart';
import 'package:ride_relay/controllers/rider_profile_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('emergency info defaults to empty and unset', () async {
    final profile = await RiderProfileController.load();

    expect(profile.emergencyContactName, isEmpty);
    expect(profile.emergencyContactPhone, isEmpty);
    expect(profile.medicalNotes, isEmpty);
    expect(profile.hasEmergencyInfo, isFalse);
  });

  test(
    'emergency info survives a fresh load, as if the app restarted',
    () async {
      final profile = await RiderProfileController.load();

      await profile.saveEmergencyInfo(
        emergencyContactName: 'Jamie Rider',
        emergencyContactPhone: '+44 7700 900123',
        medicalNotes: 'Penicillin allergy',
      );

      final reloaded = await RiderProfileController.load();
      expect(reloaded.emergencyContactName, 'Jamie Rider');
      expect(reloaded.emergencyContactPhone, '+44 7700 900123');
      expect(reloaded.medicalNotes, 'Penicillin allergy');
      expect(reloaded.hasEmergencyInfo, isTrue);
    },
  );
}
