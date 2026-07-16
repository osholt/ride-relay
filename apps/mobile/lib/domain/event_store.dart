import 'ride_event.dart';

abstract interface class EventStore {
  Future<void> append(RideEvent event);

  Future<List<RideEvent>> eventsForRide(String rideId);

  Future<List<RideEvent>> pendingEvents(String rideId);

  Future<void> markAcknowledged(String eventId);

  Future<void> deleteRide(String rideId);

  Future<void> close();
}
