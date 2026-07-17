import 'package:flutter_test/flutter_test.dart';
import 'package:ride_relay/domain/geo_point.dart';
import 'package:ride_relay/domain/ride_role.dart';
import 'package:ride_relay/domain/rider_location.dart';
import 'package:ride_relay/services/ride_completion_detector.dart';

void main() {
  const detector = RideCompletionDetector();
  final now = DateTime.utc(2026, 7, 17, 12);
  const destination = GeoPoint(latitude: 51.5, longitude: -2.5);

  test('ends only when every known rider is near the destination', () {
    final arrived = [
      _location('lead', RideRole.lead, destination, now),
      _location(
        'tec',
        RideRole.tailEndCharlie,
        const GeoPoint(latitude: 51.5003, longitude: -2.5),
        now,
      ),
    ];

    expect(
      detector.everyoneReachedDestination(
        destination: destination,
        riderLocations: arrived,
        now: now,
      ),
      isTrue,
    );
    expect(
      detector.everyoneReachedDestination(
        destination: destination,
        riderLocations: [
          ...arrived,
          _location(
            'rider',
            RideRole.rider,
            const GeoPoint(latitude: 51.51, longitude: -2.5),
            now,
          ),
        ],
        now: now,
      ),
      isFalse,
    );
  });

  test('keeps a ride open when any rider location is stale', () {
    expect(
      detector.everyoneReachedDestination(
        destination: destination,
        riderLocations: [
          _location('lead', RideRole.lead, destination, now),
          _location(
            'tec',
            RideRole.tailEndCharlie,
            destination,
            now.subtract(const Duration(minutes: 3)),
          ),
        ],
        now: now,
      ),
      isFalse,
    );
  });
}

RiderLocation _location(
  String id,
  RideRole role,
  GeoPoint point,
  DateTime recordedAt,
) => RiderLocation(
  riderId: id,
  displayName: id,
  role: role,
  sample: LocationSample(
    position: point,
    recordedAt: recordedAt,
    accuracyMeters: 5,
  ),
  receivedAt: recordedAt,
);
