import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_relay/domain/distance_unit.dart';
import 'package:ride_relay/domain/imported_route.dart';
import 'package:ride_relay/features/ride/ride_recap_card.dart';
import 'package:ride_relay/services/ride_summary_exporter.dart';

void main() {
  testWidgets('renders headline stats', (tester) async {
    final summary = _summary();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RideRecapCard(
            summary: summary,
            routePoints: const [
              GeoPoint(latitude: 51, longitude: -1),
              GeoPoint(latitude: 51.01, longitude: -1),
            ],
            distanceUnit: DistanceUnit.kilometres,
          ),
        ),
      ),
    );

    expect(find.text('RIDE ABC123'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.textContaining('km'), findsOneWidget);
  });

  testWidgets('shows a placeholder without a recorded route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RideRecapCard(summary: _summary(), routePoints: const []),
        ),
      ),
    );

    expect(find.text('No recorded route for this ride'), findsOneWidget);
  });
}

RideSummary _summary() => RideSummary(
  rideId: 'ride-1',
  rideCode: 'ABC123',
  displayName: 'Oliver',
  startedAt: DateTime.utc(2026, 7, 16, 9),
  endedAt: DateTime.utc(2026, 7, 16, 10, 30),
  generatedAt: DateTime.utc(2026, 7, 16, 10, 31),
  eventCount: 42,
  markerSessions: [
    MarkerSessionSummary(
      markerDeviceId: 'device-a',
      startedAt: DateTime.utc(2026, 7, 16, 9, 10),
      endedAt: DateTime.utc(2026, 7, 16, 9, 20),
      uniquePassCount: 7,
      duration: const Duration(minutes: 10),
    ),
  ],
  riderCount: 4,
  totalDistanceMeters: 32000,
);
