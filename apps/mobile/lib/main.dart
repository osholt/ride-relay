import 'package:flutter/material.dart';

import 'app/ride_relay_app.dart';
import 'controllers/ride_controller.dart';
import 'data/shared_preferences_session_store.dart';
import 'data/sqlite_event_store.dart';
import 'services/nearby_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = RideController(
    SqliteEventStore(),
    SharedPreferencesSessionStore(),
    const NearbyBridge(),
  );
  await controller.initialize();

  runApp(RideRelayApp(controller: controller));
}
