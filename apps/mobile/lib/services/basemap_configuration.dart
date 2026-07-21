class BasemapConfiguration {
  const BasemapConfiguration({
    this.styleUrl = '',
    this.darkStyleUrl = '',
    this.urlTemplate = '',
    this.attribution = '',
    this.cacheNamespace = '',
    this.persistentCachingAllowed = false,
    this.maximumNativeZoom = 18,
  });

  factory BasemapConfiguration.fromEnvironment() => BasemapConfiguration(
    styleUrl: const String.fromEnvironment(
      'RIDE_RELAY_MAP_STYLE_URL',
      defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
    ),
    darkStyleUrl: const String.fromEnvironment(
      'RIDE_RELAY_MAP_STYLE_URL_DARK',
      defaultValue: 'https://tiles.openfreemap.org/styles/dark',
    ),
    urlTemplate: const String.fromEnvironment('RIDE_RELAY_TILE_URL'),
    attribution: const String.fromEnvironment(
      'RIDE_RELAY_TILE_ATTRIBUTION',
      defaultValue: 'OpenFreeMap © OpenMapTiles Data from OpenStreetMap',
    ),
    cacheNamespace: const String.fromEnvironment(
      'RIDE_RELAY_TILE_CACHE_NAMESPACE',
    ),
    persistentCachingAllowed: const bool.fromEnvironment(
      'RIDE_RELAY_TILE_CACHE_ALLOWED',
    ),
    maximumNativeZoom: const int.fromEnvironment(
      'RIDE_RELAY_TILE_MAX_ZOOM',
      defaultValue: 18,
    ),
  );

  /// HTTPS MapLibre style document used by the production vector-map path.
  final String styleUrl;

  /// HTTPS MapLibre style document used at night/in dark mode. Both styles
  /// are expected to render the same underlying vector tiles, just restyled
  /// - so offline-cached tiles remain shared and reusable between them.
  final String darkStyleUrl;

  /// Legacy raster XYZ template retained as a route-only development fallback.
  final String urlTemplate;
  final String attribution;
  final String cacheNamespace;
  final bool persistentCachingAllowed;
  final int maximumNativeZoom;

  /// A copy using [darkStyleUrl] in place of [styleUrl] when [dark] is true
  /// and a dark style is actually configured; otherwise unchanged.
  BasemapConfiguration forBrightness({required bool dark}) {
    if (!dark || darkStyleUrl.trim().isEmpty) return this;
    return BasemapConfiguration(
      styleUrl: darkStyleUrl,
      darkStyleUrl: darkStyleUrl,
      urlTemplate: urlTemplate,
      attribution: attribution,
      cacheNamespace: cacheNamespace,
      persistentCachingAllowed: persistentCachingAllowed,
      maximumNativeZoom: maximumNativeZoom,
    );
  }

  bool get usesMapLibre =>
      styleUrl.trim().isNotEmpty &&
      attribution.trim().isNotEmpty &&
      _isSecureHttpUrl(styleUrl) &&
      maximumNativeZoom >= 0 &&
      maximumNativeZoom <= 22;

  bool get usesLegacyRaster =>
      urlTemplate.trim().isNotEmpty &&
      attribution.trim().isNotEmpty &&
      _hasRequiredPlaceholders(urlTemplate) &&
      _isSecureHttpTemplate(urlTemplate) &&
      maximumNativeZoom >= 0 &&
      maximumNativeZoom <= 22;

  bool get isConfigured => usesMapLibre || usesLegacyRaster;

  bool get canDownloadOffline =>
      isConfigured &&
      persistentCachingAllowed &&
      RegExp(r'^[a-zA-Z0-9._-]{1,64}$').hasMatch(cacheNamespace);

  String get statusMessage {
    if (!isConfigured) {
      return 'No MapLibre style is configured. Route geometry still works offline.';
    }
    if (!persistentCachingAllowed) {
      return 'Online basemap configured; its licence has not been approved for offline caching.';
    }
    if (!RegExp(r'^[a-zA-Z0-9._-]{1,64}$').hasMatch(cacheNamespace)) {
      return 'Offline caching needs a safe provider cache namespace.';
    }
    if (usesMapLibre) {
      return 'MapLibre vector map configured. Downloaded route regions are available offline.';
    }
    return 'Legacy raster basemap configured. Downloaded route corridors are available offline.';
  }

  static bool _hasRequiredPlaceholders(String template) =>
      template.contains('{z}') &&
      template.contains('{x}') &&
      template.contains('{y}');

  static bool _isSecureHttpTemplate(String template) {
    final uri = Uri.tryParse(
      template
          .replaceAll('{z}', '0')
          .replaceAll('{x}', '0')
          .replaceAll('{y}', '0'),
    );
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  static bool _isSecureHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}
