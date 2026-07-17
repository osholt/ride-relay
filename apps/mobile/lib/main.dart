import 'package:flutter/material.dart';

import 'app/ride_relay_app.dart';
import 'controllers/distance_unit_controller.dart';
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
  final distanceUnits = await DistanceUnitController.load(
    locale: WidgetsBinding.instance.platformDispatcher.locale,
  );

  runApp(RideRelayApp(controller: controller, distanceUnits: distanceUnits));
}
