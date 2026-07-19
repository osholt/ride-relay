import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/rider_color.dart';
import '../features/map/motorcycle_icon.dart';

/// Remembers how a rider last presented themselves - name, bike, colour -
/// so the create/join ride form starts pre-filled instead of blank every
/// time. Deliberately separate from RideSession, which is scoped to one
/// ride: this is a standalone device preference, like DistanceUnitController.
class RiderProfileController extends ChangeNotifier {
  RiderProfileController._(
    this._preferences,
    this._displayName,
    this._motorcycleStyle,
    this._riderColor,
    this._emergencyContactName,
    this._emergencyContactPhone,
    this._medicalNotes,
  );

  static const _nameKey = 'rider_profile_display_name';
  static const _styleKey = 'rider_profile_motorcycle_style';
  static const _colorKey = 'rider_profile_colour';
  static const _emergencyContactNameKey = 'rider_profile_ice_contact_name';
  static const _emergencyContactPhoneKey = 'rider_profile_ice_contact_phone';
  static const _medicalNotesKey = 'rider_profile_ice_medical_notes';

  final SharedPreferences _preferences;
  String _displayName;
  MotorcycleIconStyle _motorcycleStyle;
  RiderColor _riderColor;
  String _emergencyContactName;
  String _emergencyContactPhone;
  String _medicalNotes;

  String get displayName => _displayName;
  MotorcycleIconStyle get motorcycleStyle => _motorcycleStyle;
  RiderColor get riderColor => _riderColor;

  // In-case-of-emergency details. Deliberately device-local only: never read
  // by RideSession/RideEvent, so it can never reach the relay, the event
  // journal, or another rider's device.
  String get emergencyContactName => _emergencyContactName;
  String get emergencyContactPhone => _emergencyContactPhone;
  String get medicalNotes => _medicalNotes;
  bool get hasEmergencyInfo =>
      _emergencyContactName.isNotEmpty ||
      _emergencyContactPhone.isNotEmpty ||
      _medicalNotes.isNotEmpty;

  static Future<RiderProfileController> load() async {
    final preferences = await SharedPreferences.getInstance();
    return RiderProfileController._(
      preferences,
      preferences.getString(_nameKey) ?? '',
      motorcycleIconStyleFromName(preferences.getString(_styleKey)),
      riderColorFromName(preferences.getString(_colorKey)),
      preferences.getString(_emergencyContactNameKey) ?? '',
      preferences.getString(_emergencyContactPhoneKey) ?? '',
      preferences.getString(_medicalNotesKey) ?? '',
    );
  }

  Future<void> save({
    required String displayName,
    required MotorcycleIconStyle motorcycleStyle,
    required RiderColor riderColor,
  }) async {
    _displayName = displayName;
    _motorcycleStyle = motorcycleStyle;
    _riderColor = riderColor;
    await Future.wait([
      _preferences.setString(_nameKey, displayName),
      _preferences.setString(_styleKey, motorcycleStyle.name),
      _preferences.setString(_colorKey, riderColor.name),
    ]);
    notifyListeners();
  }

  Future<void> saveEmergencyInfo({
    required String emergencyContactName,
    required String emergencyContactPhone,
    required String medicalNotes,
  }) async {
    _emergencyContactName = emergencyContactName;
    _emergencyContactPhone = emergencyContactPhone;
    _medicalNotes = medicalNotes;
    await Future.wait([
      _preferences.setString(_emergencyContactNameKey, emergencyContactName),
      _preferences.setString(_emergencyContactPhoneKey, emergencyContactPhone),
      _preferences.setString(_medicalNotesKey, medicalNotes),
    ]);
    notifyListeners();
  }
}
