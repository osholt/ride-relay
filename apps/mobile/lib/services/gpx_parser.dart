import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../domain/imported_route.dart';

class GpxParser {
  const GpxParser({
    this.maximumBytes = 10 * 1024 * 1024,
    this.maximumPoints = 200000,
  });

  final int maximumBytes;
  final int maximumPoints;

  ImportedRoute parse(
    Uint8List bytes, {
    required String routeId,
    required String sourceFileName,
    required DateTime importedAt,
  }) {
    if (bytes.isEmpty) {
      throw const GpxFormatException('The GPX file is empty.');
    }
    if (bytes.length > maximumBytes) {
      throw GpxFormatException(
        'The GPX file exceeds the ${maximumBytes ~/ (1024 * 1024)} MB import limit.',
      );
    }

    final String source;
    try {
      source = utf8.decode(bytes);
    } on FormatException {
      throw const GpxFormatException('The GPX file must use UTF-8 encoding.');
    }
    if (source.toUpperCase().contains('<!DOCTYPE')) {
      throw const GpxFormatException(
        'GPX files containing a document type declaration are not accepted.',
      );
    }

    final XmlDocument document;
    try {
      document = XmlDocument.parse(source);
    } on XmlParserException catch (error) {
      throw GpxFormatException('Invalid GPX XML: ${error.message}');
    }
    final root = document.rootElement;
    if (root.name.local.toLowerCase() != 'gpx') {
      throw const GpxFormatException('The document root must be <gpx>.');
    }

    var pointCount = 0;
    GeoPoint parsePoint(XmlElement element) {
      pointCount += 1;
      if (pointCount > maximumPoints) {
        throw GpxFormatException(
          'The GPX file exceeds the $maximumPoints point import limit.',
        );
      }
      final latitude = _coordinate(element, 'lat', -90, 90);
      final longitude = _coordinate(element, 'lon', -180, 180);
      final elevation = _optionalDouble(_childText(element, 'ele'));
      final timeText = _childText(element, 'time');
      DateTime? recordedAt;
      if (timeText != null) {
        recordedAt = DateTime.tryParse(timeText)?.toUtc();
      }
      return GeoPoint(
        latitude: latitude,
        longitude: longitude,
        elevationMeters: elevation,
        recordedAt: recordedAt,
      );
    }

    final paths = <RoutePath>[];
    for (final track in _children(root, 'trk')) {
      final trackName = _childText(track, 'name');
      final isCalculatedRoadRoute = _children(track, 'extensions')
          .expand((extensions) => extensions.childElements)
          .any(
            (element) =>
                element.name.local.toLowerCase() == 'road-route' &&
                element.innerText.trim().toLowerCase() == 'true',
          );
      final segments = _children(track, 'trkseg').toList(growable: false);
      for (var index = 0; index < segments.length; index += 1) {
        final points = _children(
          segments[index],
          'trkpt',
        ).map(parsePoint).toList(growable: false);
        if (points.isEmpty) continue;
        final segmentName = segments.length > 1 && trackName != null
            ? '$trackName · segment ${index + 1}'
            : trackName;
        paths.add(
          RoutePath(
            kind: isCalculatedRoadRoute
                ? RoutePathKind.route
                : RoutePathKind.track,
            name: segmentName,
            points: points,
          ),
        );
      }
    }
    final routeElements = _routesForImport(root);
    final routeWaypoints = <RouteWaypoint>[];
    for (final route in routeElements) {
      final points = <GeoPoint>[];
      for (final routePoint in _children(route, 'rtept')) {
        final point = parsePoint(routePoint);
        points.add(point);
        final pointKind = _routePointKind(routePoint);
        if (pointKind != null) {
          routeWaypoints.add(
            RouteWaypoint(
              point: point,
              name: _childText(routePoint, 'name'),
              description: pointKind == 'shaping'
                  ? 'Soft route shaping point'
                  : 'Route via point',
              symbol: pointKind == 'shaping' ? 'Shaping point' : 'Via point',
            ),
          );
        }
        for (final shapingPoint in _routePointExtensionPoints(routePoint)) {
          final shapingPosition = parsePoint(shapingPoint);
          points.add(shapingPosition);
          routeWaypoints.add(
            RouteWaypoint(
              point: shapingPosition,
              name: 'Shaping point ${routeWaypoints.length + 1}',
              description: 'Soft route shaping point',
              symbol: 'Shaping point',
            ),
          );
        }
      }
      if (points.isEmpty) continue;
      paths.add(
        RoutePath(
          kind: RoutePathKind.route,
          name: _childText(route, 'name'),
          points: points,
        ),
      );
    }

    final waypoints = _children(root, 'wpt')
        .map(
          (waypoint) => RouteWaypoint(
            point: parsePoint(waypoint),
            name: _childText(waypoint, 'name'),
            description:
                _childText(waypoint, 'desc') ?? _childText(waypoint, 'cmt'),
            symbol: _childText(waypoint, 'sym'),
          ),
        )
        .toList();
    for (final routeWaypoint in routeWaypoints) {
      final duplicate = waypoints.any(
        (waypoint) =>
            (waypoint.point.latitude - routeWaypoint.point.latitude).abs() <
                0.000001 &&
            (waypoint.point.longitude - routeWaypoint.point.longitude).abs() <
                0.000001,
      );
      if (!duplicate) waypoints.add(routeWaypoint);
    }

    if (paths.isEmpty && waypoints.isEmpty) {
      throw const GpxFormatException(
        'The GPX file contains no tracks, routes, or waypoints.',
      );
    }
    final metadata = _children(root, 'metadata').firstOrNull;
    final metadataName = metadata == null ? null : _childText(metadata, 'name');
    final firstPathName = paths.map((path) => path.name).nonNulls.firstOrNull;

    return ImportedRoute(
      id: routeId,
      name:
          metadataName ??
          firstPathName ??
          _nameWithoutExtension(sourceFileName),
      description: metadata == null ? null : _childText(metadata, 'desc'),
      importedAt: importedAt.toUtc(),
      sourceFileName: sourceFileName,
      paths: paths,
      waypoints: List.unmodifiable(waypoints),
    );
  }
}

class GpxFormatException implements FormatException {
  const GpxFormatException(this.message);

  @override
  final String message;

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => 'GpxFormatException: $message';
}

Iterable<XmlElement> _children(XmlElement parent, String localName) => parent
    .childElements
    .where((element) => element.name.local.toLowerCase() == localName);

List<XmlElement> _routesForImport(XmlElement root) {
  final routes = _children(root, 'rte').toList(growable: false);
  final creator = root.getAttribute('creator')?.toLowerCase() ?? '';
  if (!creator.contains('scenic') || routes.length < 2) return routes;

  // Scenic exports plain GPX, Garmin Trip and Garmin RoutePoint versions of
  // the same route in one document. Importing all three creates overlapping,
  // differently recalculated paths. Select the richest representation,
  // preferring explicit shaping/via semantics when point coverage ties.
  XmlElement selected = routes.first;
  var selectedScore = _routeRepresentationScore(selected);
  for (final route in routes.skip(1)) {
    final score = _routeRepresentationScore(route);
    if (score > selectedScore) {
      selected = route;
      selectedScore = score;
    }
  }
  return [selected];
}

int _routeRepresentationScore(XmlElement route) {
  var effectivePoints = 0;
  var semanticPoints = 0;
  for (final routePoint in _children(route, 'rtept')) {
    effectivePoints += 1 + _routePointExtensionPoints(routePoint).length;
    if (_routePointKind(routePoint) != null) semanticPoints += 1;
  }
  return effectivePoints * 1000 + semanticPoints;
}

String? _routePointKind(XmlElement routePoint) {
  for (final element in routePoint.descendantElements) {
    switch (element.name.local.toLowerCase()) {
      case 'shapingpoint':
        return 'shaping';
      case 'viapoint':
        return 'via';
    }
  }
  return null;
}

List<XmlElement> _routePointExtensionPoints(XmlElement routePoint) => routePoint
    .descendantElements
    .where((element) => element.name.local.toLowerCase() == 'rpt')
    .toList(growable: false);

String? _childText(XmlElement parent, String localName) {
  final element = _children(parent, localName).firstOrNull;
  final value = element?.innerText.trim();
  return value == null || value.isEmpty ? null : value;
}

double _coordinate(
  XmlElement element,
  String attributeName,
  double minimum,
  double maximum,
) {
  final raw = element.getAttribute(attributeName);
  final value = double.tryParse(raw ?? '');
  if (value == null || !value.isFinite || value < minimum || value > maximum) {
    throw GpxFormatException(
      '<${element.name.local}> has an invalid $attributeName coordinate.',
    );
  }
  return value;
}

double? _optionalDouble(String? raw) {
  if (raw == null) return null;
  final value = double.tryParse(raw);
  return value != null && value.isFinite ? value : null;
}

String _nameWithoutExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final name = dot > 0 ? fileName.substring(0, dot) : fileName;
  return name.trim().isEmpty ? 'Imported route' : name.trim();
}
