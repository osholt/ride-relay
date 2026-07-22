import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/imported_route.dart';

enum MotorcycleDiscoveryCategory {
  twistyHighlight('twisty_highlight', 'Twisty highlights'),
  mountainPass('mountain_pass', 'Mountain passes'),
  goodBikingRoad('good_biking_road', 'Good biking roads');

  const MotorcycleDiscoveryCategory(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class MotorcycleDiscoveryFeature {
  const MotorcycleDiscoveryFeature({
    required this.id,
    required this.category,
    required this.name,
    required this.points,
    required this.sourceName,
    required this.sourceUrl,
    required this.confidence,
    required this.lastVerified,
    required this.warning,
    this.score,
  });

  final String id;
  final MotorcycleDiscoveryCategory category;
  final String name;
  final List<GeoPoint> points;
  final String sourceName;
  final String sourceUrl;
  final String confidence;
  final String lastVerified;
  final String warning;
  final int? score;

  bool get isPoint => points.length == 1;
  GeoPoint get anchor => points[points.length ~/ 2];
}

class MotorcycleDiscoveryCatalogue {
  const MotorcycleDiscoveryCatalogue(this.features);

  final List<MotorcycleDiscoveryFeature> features;

  static Future<MotorcycleDiscoveryCatalogue> loadAsset() async =>
      MotorcycleDiscoveryCatalogue.fromJson(
        await rootBundle.loadString('assets/discovery_catalogue.geojson'),
      );

  factory MotorcycleDiscoveryCatalogue.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map || decoded['type'] != 'FeatureCollection') {
      throw const FormatException('Discovery catalogue must be GeoJSON.');
    }
    final rawFeatures = decoded['features'];
    if (rawFeatures is! List || rawFeatures.length > 10_000) {
      throw const FormatException(
        'Discovery catalogue feature list is invalid.',
      );
    }
    return MotorcycleDiscoveryCatalogue(
      List.unmodifiable(rawFeatures.map(_parseFeature)),
    );
  }

  List<MotorcycleDiscoveryFeature> visible({
    required Set<MotorcycleDiscoveryCategory> categories,
    double west = -180,
    double south = -90,
    double east = 180,
    double north = 90,
  }) => features
      .where(
        (feature) =>
            categories.contains(feature.category) &&
            feature.points.any(
              (point) =>
                  point.longitude >= west &&
                  point.longitude <= east &&
                  point.latitude >= south &&
                  point.latitude <= north,
            ),
      )
      .toList(growable: false);

  static MotorcycleDiscoveryFeature _parseFeature(Object? raw) {
    if (raw is! Map || raw['properties'] is! Map || raw['geometry'] is! Map) {
      throw const FormatException('Discovery feature is invalid.');
    }
    final properties = Map<String, Object?>.from(raw['properties'] as Map);
    final geometry = Map<String, Object?>.from(raw['geometry'] as Map);
    final categoryValue = properties['category'];
    final categories = MotorcycleDiscoveryCategory.values.where(
      (category) => category.apiValue == categoryValue,
    );
    if (categories.isEmpty) {
      throw FormatException('Unsupported discovery category: $categoryValue');
    }
    final rawCoordinates = geometry['coordinates'];
    final pointCoordinates = geometry['type'] == 'Point'
        ? [rawCoordinates]
        : rawCoordinates;
    if (pointCoordinates is! List || pointCoordinates.isEmpty) {
      throw const FormatException('Discovery geometry is empty.');
    }
    final points = pointCoordinates
        .map((rawPoint) {
          if (rawPoint is! List ||
              rawPoint.length != 2 ||
              rawPoint[0] is! num ||
              rawPoint[1] is! num) {
            throw const FormatException('Discovery coordinate is invalid.');
          }
          return GeoPoint(
            longitude: (rawPoint[0] as num).toDouble(),
            latitude: (rawPoint[1] as num).toDouble(),
          );
        })
        .toList(growable: false);
    return MotorcycleDiscoveryFeature(
      id: _required(properties, 'id'),
      category: categories.single,
      name: _required(properties, 'name'),
      points: points,
      sourceName: _required(properties, 'sourceName'),
      sourceUrl: _required(properties, 'sourceUrl'),
      confidence: _required(properties, 'confidence'),
      lastVerified: _required(properties, 'lastVerified'),
      warning: _required(properties, 'warning'),
      score: (properties['score'] as num?)?.round(),
    );
  }

  static String _required(Map<String, Object?> values, String key) {
    final value = values[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Discovery $key is required.');
    }
    return value.trim();
  }
}
