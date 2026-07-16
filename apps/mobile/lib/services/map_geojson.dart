import '../domain/imported_route.dart';

class MapGeoJsonPoint {
  const MapGeoJsonPoint({
    required this.id,
    required this.point,
    this.properties = const {},
  });

  final String id;
  final GeoPoint point;
  final Map<String, Object?> properties;
}

class MapGeoJson {
  const MapGeoJson._();

  static Map<String, dynamic> route(ImportedRoute? route) => {
    'type': 'FeatureCollection',
    'features': route == null
        ? <Map<String, dynamic>>[]
        : route.paths.indexed
              .where((entry) => entry.$2.points.length >= 2)
              .map(
                (entry) => <String, dynamic>{
                  'type': 'Feature',
                  'id': 'route-path-${entry.$1}',
                  'properties': const <String, Object?>{},
                  'geometry': {
                    'type': 'LineString',
                    'coordinates': entry.$2.points
                        .map((point) => [point.longitude, point.latitude])
                        .toList(growable: false),
                  },
                },
              )
              .toList(growable: false),
  };

  static Map<String, dynamic> points(Iterable<MapGeoJsonPoint> points) => {
    'type': 'FeatureCollection',
    'features': points
        .map(
          (item) => <String, dynamic>{
            'type': 'Feature',
            'id': item.id,
            'properties': item.properties,
            'geometry': {
              'type': 'Point',
              'coordinates': [item.point.longitude, item.point.latitude],
            },
          },
        )
        .toList(growable: false),
  };
}
