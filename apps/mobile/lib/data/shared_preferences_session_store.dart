import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ride_session.dart';
import '../domain/session_store.dart';

class SharedPreferencesSessionStore implements SessionStore {
  static const _sessionKey = 'active_ride_session_v1';

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }

  @override
  Future<RideSession?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_sessionKey);
    if (encoded == null) {
      return null;
    }

    try {
      return RideSession.fromJson(
        Map<String, Object?>.from(jsonDecode(encoded) as Map),
      );
    } on FormatException {
      await preferences.remove(_sessionKey);
      return null;
    } on TypeError {
      await preferences.remove(_sessionKey);
      return null;
    }
  }

  @override
  Future<void> save(RideSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionKey, jsonEncode(session.toJson()));
  }
}
