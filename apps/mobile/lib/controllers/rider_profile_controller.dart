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
    this._shareIceWithLeaderByDefault,
  );

  static const _nameKey = 'rider_profile_display_name';
  static const _styleKey = 'rider_profile_motorcycle_style';
  static const _colorKey = 'rider_profile_colour';
  static const _emergencyContactNameKey = 'rider_profile_ice_contact_name';
  static const _emergencyContactPhoneKey = 'rider_profile_ice_contact_phone';
  static const _medicalNotesKey = 'rider_profile_ice_medical_notes';
  static const _shareIceWithLeaderByDefaultKey =
      'rider_profile_ice_share_with_leader_default';

  final SharedPreferences _preferences;
  String _displayName;
  MotorcycleIconStyle _motorcycleStyle;
  RiderColor _riderColor;
  String _emergencyContactName;
  String _emergencyContactPhone;
  String _medicalNotes;
  bool _shareIceWithLeaderByDefault;

  String get displayName => _displayName;
  MotorcycleIconStyle get motorcycleStyle => _motorcycleStyle;
  RiderColor get riderColor => _riderColor;

  // In-case-of-emergency details. Kept device-local by default: not read by
  // RideSession/RideEvent, so ordinary ride events never carry it. It only
  // ever leaves the device through an explicit share action, or the opt-in
  // auto-share-with-leader setting below - both driven from RideController,
  // never automatically.
  String get emergencyContactName => _emergencyContactName;
  String get emergencyContactPhone => _emergencyContactPhone;
  String get medicalNotes => _medicalNotes;
  bool get hasEmergencyInfo =>
      _emergencyContactName.isNotEmpty ||
      _emergencyContactPhone.isNotEmpty ||
      _medicalNotes.isNotEmpty;

  /// If true, triggering an emergency-stop alert also shares this rider's
  /// ICE info with whoever currently holds the lead role, without a further
  /// explicit step - so it still happens if the rider can't act again.
  bool get shareIceWithLeaderByDefault => _shareIceWithLeaderByDefault;

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
      preferences.getBool(_shareIceWithLeaderByDefaultKey) ?? false,
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
    required bool shareWithLeaderByDefault,
  }) async {
    _emergencyContactName = emergencyContactName;
    _emergencyContactPhone = emergencyContactPhone;
    _medicalNotes = medicalNotes;
    _shareIceWithLeaderByDefault = shareWithLeaderByDefault;
    await Future.wait([
      _preferences.setString(_emergencyContactNameKey, emergencyContactName),
      _preferences.setString(_emergencyContactPhoneKey, emergencyContactPhone),
      _preferences.setString(_medicalNotesKey, medicalNotes),
      _preferences.setBool(
        _shareIceWithLeaderByDefaultKey,
        shareWithLeaderByDefault,
      ),
    ]);
    notifyListeners();
  }
}
