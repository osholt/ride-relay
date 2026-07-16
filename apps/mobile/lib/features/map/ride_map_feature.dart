import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:uuid/uuid.dart';

import '../../data/json_file_route_store.dart';
import '../../domain/imported_route.dart';
import '../../domain/route_store.dart';
import '../../services/basemap_configuration.dart';
import '../../services/gpx_import_source.dart';
import '../../services/gpx_parser.dart';
import '../../services/map_geojson.dart';
import '../../services/map_style_repository.dart';
import '../../services/maplibre_offline_manager.dart';
import '../../services/navigation_export.dart';
import '../../services/offline_tile_cache.dart';
import '../../services/route_importer.dart';
import 'navigation_export_sheet.dart';

/// Self-contained production entry point for the map/GPX feature.
///
/// Route geometry is local and always renders without a network. Basemap tiles
/// are only enabled when [BasemapConfiguration] contains a provider URL and
/// attribution. Offline tile downloads additionally require explicit provider
/// cache permission.
class RideMapFeature extends StatefulWidget {
  const RideMapFeature({
    super.key,
    this.currentPosition,
    this.overlayMarkers,
    this.onRouteChanged,
    this.navigationExportCoordinator,
    this.basemapConfiguration = const BasemapConfiguration(),
  });

  factory RideMapFeature.fromEnvironment({
    Key? key,
    ValueListenable<GeoPoint?>? currentPosition,
    ValueListenable<List<MapOverlayMarker>>? overlayMarkers,
    ValueChanged<ImportedRoute?>? onRouteChanged,
  }) => RideMapFeature(
    key: key,
    currentPosition: currentPosition,
    overlayMarkers: overlayMarkers,
    onRouteChanged: onRouteChanged,
    basemapConfiguration: BasemapConfiguration.fromEnvironment(),
  );

  final ValueListenable<GeoPoint?>? currentPosition;
  final ValueListenable<List<MapOverlayMarker>>? overlayMarkers;
  final ValueChanged<ImportedRoute?>? onRouteChanged;
  final NavigationExportCoordinator? navigationExportCoordinator;
  final BasemapConfiguration basemapConfiguration;

  @override
  State<RideMapFeature> createState() => _RideMapFeatureState();
}

class _RideMapFeatureState extends State<RideMapFeature> {
  late Future<_MapDependencies> _dependencies;

  @override
  void initState() {
    super.initState();
    _dependencies = _openDependencies();
  }

  Future<_MapDependencies> _openDependencies() async {
    final styleRepository = await MapStyleRepository.openDefault(
      widget.basemapConfiguration,
    );
    try {
      return _MapDependencies(
        store: await JsonFileRouteStore.openDefault(),
        cache: await OfflineTileCache.openDefault(widget.basemapConfiguration),
        mapLibreOfflineManager: MapLibreOfflineManager(
          configuration: widget.basemapConfiguration,
        ),
        mapStyleString: await styleRepository.resolve(),
      );
    } finally {
      styleRepository.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_MapDependencies>(
    future: _dependencies,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Route map')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not open route storage: ${snapshot.error}'),
            ),
          ),
        );
      }
      final dependencies = snapshot.data;
      if (dependencies == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return RideMapScreen(
        routeStore: dependencies.store,
        routeImporter: RouteImporter(source: const SystemGpxImportSource()),
        offlineTileCache: dependencies.cache,
        mapLibreOfflineManager: dependencies.mapLibreOfflineManager,
        mapStyleString: dependencies.mapStyleString,
        disposeOfflineTileCache: true,
        currentPosition: widget.currentPosition,
        overlayMarkers: widget.overlayMarkers,
        onRouteChanged: widget.onRouteChanged,
        navigationExportCoordinator: widget.navigationExportCoordinator,
      );
    },
  );
}

class _MapDependencies {
  const _MapDependencies({
    required this.store,
    required this.cache,
    required this.mapLibreOfflineManager,
    required this.mapStyleString,
  });

  final RouteStore store;
  final OfflineTileCache cache;
  final MapLibreOfflineManager mapLibreOfflineManager;
  final String mapStyleString;
}

/// Injectable map screen used by app integration and focused tests.
class RideMapScreen extends StatefulWidget {
  const RideMapScreen({
    super.key,
    required this.routeStore,
    required this.routeImporter,
    required this.offlineTileCache,
    this.mapLibreOfflineManager,
    this.mapStyleString = MapStyleRepository.fallbackStyle,
    this.currentPosition,
    this.overlayMarkers,
    this.onRouteChanged,
    this.navigationExportCoordinator,
    this.demoRouteLoader,
    this.disposeOfflineTileCache = false,
  });

  final RouteStore routeStore;
  final RouteImporter routeImporter;
  final OfflineTileCache offlineTileCache;
  final MapLibreOfflineManager? mapLibreOfflineManager;
  final String mapStyleString;
  final ValueListenable<GeoPoint?>? currentPosition;
  final ValueListenable<List<MapOverlayMarker>>? overlayMarkers;
  final ValueChanged<ImportedRoute?>? onRouteChanged;
  final NavigationExportCoordinator? navigationExportCoordinator;
  final Future<ImportedRoute> Function()? demoRouteLoader;
  final bool disposeOfflineTileCache;

  @override
  State<RideMapScreen> createState() => _RideMapScreenState();
}

class _RideMapScreenState extends State<RideMapScreen> {
  static const _routeSource = 'ride-relay-route';
  static const _waypointSource = 'ride-relay-waypoints';
  static const _positionSource = 'ride-relay-position';
  static const _overlaySource = 'ride-relay-overlays';

  final MapController _mapController = MapController();
  ml.MapLibreMapController? _mapLibreController;
  late final MapLibreOfflineManager _mapLibreOfflineManager;
  bool _mapLibreStyleReady = false;
  ImportedRoute? _route;
  Object? _loadError;
  bool _loading = true;
  bool _importing = false;
  bool _exporting = false;
  TileDownloadProgress? _downloadProgress;
  TileDownloadCancellationToken? _downloadCancellation;

  BasemapConfiguration get _basemap => widget.offlineTileCache.configuration;

  @override
  void initState() {
    super.initState();
    _mapLibreOfflineManager =
        widget.mapLibreOfflineManager ??
        MapLibreOfflineManager(configuration: _basemap);
    widget.currentPosition?.addListener(_onMapDataChanged);
    widget.overlayMarkers?.addListener(_onMapDataChanged);
    _loadPersistedRoute();
  }

  @override
  void didUpdateWidget(RideMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPosition != widget.currentPosition) {
      oldWidget.currentPosition?.removeListener(_onMapDataChanged);
      widget.currentPosition?.addListener(_onMapDataChanged);
    }
    if (oldWidget.overlayMarkers != widget.overlayMarkers) {
      oldWidget.overlayMarkers?.removeListener(_onMapDataChanged);
      widget.overlayMarkers?.addListener(_onMapDataChanged);
    }
  }

  @override
  void dispose() {
    _downloadCancellation?.cancel();
    widget.currentPosition?.removeListener(_onMapDataChanged);
    widget.overlayMarkers?.removeListener(_onMapDataChanged);
    _mapLibreController?.onFeatureTapped.remove(_onMapLibreFeatureTapped);
    _mapController.dispose();
    if (widget.disposeOfflineTileCache) widget.offlineTileCache.dispose();
    super.dispose();
  }

  Future<void> _loadPersistedRoute() async {
    try {
      final route = await widget.routeStore.loadActiveRoute();
      if (!mounted) return;
      setState(() {
        _route = route;
        _loading = false;
      });
      widget.onRouteChanged?.call(route);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _route?.name ?? 'Navigation',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_route == null)
            IconButton(
              tooltip: 'Import GPX route',
              onPressed: _importing ? null : _importGpx,
              icon: _importing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
            ),
          if (_route != null)
            IconButton(
              tooltip: 'Navigate or export route',
              onPressed: _exporting ? null : _openNavigationExport,
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.alt_route),
            ),
          IconButton(
            tooltip: 'Fit route',
            onPressed: _route == null ? null : _fitRoute,
            icon: const Icon(Icons.fit_screen),
          ),
          PopupMenuButton<_MapAction>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _MapAction.importGpx,
                child: Text(
                  _route == null ? 'Import GPX route' : 'Replace GPX route',
                ),
              ),
              const PopupMenuItem(
                value: _MapAction.loadDemo,
                child: Text('Load demo route'),
              ),
              if (_route != null)
                PopupMenuItem(
                  value: _MapAction.downloadOffline,
                  enabled:
                      _basemap.canDownloadOffline && _downloadProgress == null,
                  child: Text(
                    _basemap.canDownloadOffline
                        ? 'Download map for offline use'
                        : 'Offline map download unavailable',
                  ),
                ),
              const PopupMenuItem(
                value: _MapAction.clearOfflineTiles,
                child: Text('Clear downloaded map data'),
              ),
              if (_route != null)
                const PopupMenuItem(
                  value: _MapAction.removeRoute,
                  child: Text('Remove route'),
                ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _ErrorState(error: _loadError!, onRetry: _loadPersistedRoute)
          : Stack(
              children: [
                Positioned.fill(child: _buildMap()),
                if (_downloadProgress case final progress?)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: Card(
                      child: _DownloadProgress(
                        progress: progress,
                        onCancel: _downloadCancellation?.cancel,
                      ),
                    ),
                  ),
                if (_route == null)
                  Positioned.fill(
                    child: _EmptyRoutePrompt(
                      importing: _importing,
                      onImport: _importGpx,
                      onLoadDemo: _loadDemoRoute,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildMap() {
    if (_basemap.usesMapLibre) return _buildMapLibreMap();

    final route = _route;
    final points = route?.allPoints.map(_latLng).toList(growable: false) ?? [];
    final options = points.length > 1
        ? MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(42),
            ),
            initialZoom: 13,
          )
        : MapOptions(
            initialCenter: points.firstOrNull ?? const LatLng(54.5, -3.2),
            initialZoom: points.isEmpty ? 5 : 14,
          );

    final map = FlutterMap(
      key: ValueKey(route?.id ?? 'empty-map'),
      mapController: _mapController,
      options: options,
      children: [
        if (_basemap.usesLegacyRaster)
          TileLayer(
            urlTemplate: _basemap.urlTemplate,
            userAgentPackageName: 'me.osholt.ride_relay',
            maxNativeZoom: _basemap.maximumNativeZoom,
            tileProvider: LicensedCachingTileProvider(
              cache: widget.offlineTileCache,
            ),
          ),
        if (route != null)
          PolylineLayer(
            polylines: route.paths
                .map(
                  (path) => Polyline(
                    points: path.points.map(_latLng).toList(growable: false),
                    color: const Color(0xFFFF7A1A),
                    strokeWidth: 5,
                    borderColor: const Color(0xFF10151C),
                    borderStrokeWidth: 2,
                  ),
                )
                .toList(growable: false),
          ),
        if (route != null && route.waypoints.isNotEmpty)
          MarkerLayer(
            markers: route.waypoints
                .take(500)
                .map(
                  (waypoint) => Marker(
                    point: _latLng(waypoint.point),
                    width: 42,
                    height: 42,
                    child: Tooltip(
                      message: waypoint.name ?? 'GPX waypoint',
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xFFFFC857),
                        size: 36,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        if (widget.currentPosition != null)
          ValueListenableBuilder<GeoPoint?>(
            valueListenable: widget.currentPosition!,
            builder: (context, currentPosition, _) => currentPosition == null
                ? const SizedBox.shrink()
                : MarkerLayer(
                    markers: [
                      Marker(
                        point: _latLng(currentPosition),
                        width: 34,
                        height: 34,
                        child: const _CurrentPositionMarker(),
                      ),
                    ],
                  ),
          ),
        if (widget.overlayMarkers != null)
          ValueListenableBuilder<List<MapOverlayMarker>>(
            valueListenable: widget.overlayMarkers!,
            builder: (context, overlays, _) => MarkerLayer(
              markers: overlays
                  .take(1000)
                  .map(
                    (overlay) => Marker(
                      key: ValueKey(overlay.id),
                      point: _latLng(overlay.point),
                      width: 42,
                      height: 42,
                      child: Tooltip(
                        message: overlay.label,
                        child: Icon(
                          overlay.icon,
                          color: overlay.color,
                          size: 34,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        if (_basemap.usesLegacyRaster)
          SimpleAttributionWidget(
            source: Text(
              _basemap.attribution,
              style: const TextStyle(fontSize: 10),
            ),
            backgroundColor: const Color(0xCC171D25),
          ),
      ],
    );

    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: const Color(0xFF111820), child: map),
        ),
        if (!_basemap.isConfigured)
          const Positioned(left: 12, bottom: 12, child: _RouteOnlyBadge()),
      ],
    );
  }

  Widget _buildMapLibreMap() {
    final routePoints = _route?.allPoints.toList(growable: false) ?? const [];
    final initial = routePoints.isEmpty
        ? const ml.CameraPosition(target: ml.LatLng(54.5, -3.2), zoom: 5)
        : ml.CameraPosition(
            target: ml.LatLng(
              routePoints.first.latitude,
              routePoints.first.longitude,
            ),
            zoom: routePoints.length == 1 ? 14 : 11,
          );
    return Stack(
      children: [
        Positioned.fill(
          child: ml.MapLibreMap(
            styleString: widget.mapStyleString,
            initialCameraPosition: initial,
            onMapCreated: _onMapLibreCreated,
            onStyleLoadedCallback: () => unawaited(_prepareMapLibreStyle()),
            logoEnabled: false,
            compassEnabled: true,
            minMaxZoomPreference: ml.MinMaxZoomPreference(
              3,
              _basemap.maximumNativeZoom.toDouble(),
            ),
          ),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: _MapAttributionBadge(text: _basemap.attribution),
        ),
      ],
    );
  }

  void _onMapLibreCreated(ml.MapLibreMapController controller) {
    _mapLibreController?.onFeatureTapped.remove(_onMapLibreFeatureTapped);
    _mapLibreController = controller;
    controller.onFeatureTapped.add(_onMapLibreFeatureTapped);
  }

  Future<void> _prepareMapLibreStyle() async {
    final controller = _mapLibreController;
    if (controller == null) return;
    _mapLibreStyleReady = false;
    try {
      await controller.addGeoJsonSource(_routeSource, MapGeoJson.route(_route));
      await controller.addLineLayer(
        _routeSource,
        'ride-relay-route-border',
        const ml.LineLayerProperties(
          lineColor: '#10151C',
          lineWidth: 9,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );
      await controller.addLineLayer(
        _routeSource,
        'ride-relay-route-line',
        const ml.LineLayerProperties(
          lineColor: '#FF7A1A',
          lineWidth: 5,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );
      await controller.addGeoJsonSource(_waypointSource, _waypointGeoJson());
      await controller.addCircleLayer(
        _waypointSource,
        'ride-relay-waypoint-circles',
        const ml.CircleLayerProperties(
          circleRadius: 7,
          circleColor: '#FFC857',
          circleStrokeWidth: 2,
          circleStrokeColor: '#10151C',
        ),
      );
      await controller.addGeoJsonSource(_positionSource, _positionGeoJson());
      await controller.addCircleLayer(
        _positionSource,
        'ride-relay-position-circle',
        const ml.CircleLayerProperties(
          circleRadius: 8,
          circleColor: '#FFFFFF',
          circleStrokeWidth: 4,
          circleStrokeColor: '#2F80ED',
        ),
        enableInteraction: false,
      );
      await controller.addGeoJsonSource(_overlaySource, _overlayGeoJson());
      await controller.addCircleLayer(
        _overlaySource,
        'ride-relay-overlay-circles',
        const ml.CircleLayerProperties(
          circleRadius: 9,
          circleColor: ['get', 'color'],
          circleStrokeWidth: 2,
          circleStrokeColor: '#10151C',
        ),
      );
      _mapLibreStyleReady = true;
      await _syncMapLibreSources();
      _fitRoute();
    } on Object catch (error, stackTrace) {
      debugPrint('Could not prepare MapLibre ride layers: $error\n$stackTrace');
    }
  }

  void _onMapDataChanged() => unawaited(_syncMapLibreSources());

  Future<void> _syncMapLibreSources() async {
    final controller = _mapLibreController;
    if (!_mapLibreStyleReady || controller == null) return;
    try {
      await controller.setGeoJsonSource(_routeSource, MapGeoJson.route(_route));
      await controller.setGeoJsonSource(_waypointSource, _waypointGeoJson());
      await controller.setGeoJsonSource(_positionSource, _positionGeoJson());
      await controller.setGeoJsonSource(_overlaySource, _overlayGeoJson());
    } on Object catch (error) {
      debugPrint('Could not refresh MapLibre ride layers: $error');
    }
  }

  Map<String, dynamic> _waypointGeoJson() => MapGeoJson.points(
    _route?.waypoints
            .take(500)
            .indexed
            .map(
              (entry) => MapGeoJsonPoint(
                id: 'waypoint-${entry.$1}',
                point: entry.$2.point,
                properties: {'label': entry.$2.name ?? 'GPX waypoint'},
              ),
            ) ??
        const <MapGeoJsonPoint>[],
  );

  Map<String, dynamic> _positionGeoJson() {
    final point = widget.currentPosition?.value;
    return MapGeoJson.points(
      point == null
          ? const <MapGeoJsonPoint>[]
          : [MapGeoJsonPoint(id: 'current-position', point: point)],
    );
  }

  Map<String, dynamic> _overlayGeoJson() => MapGeoJson.points(
    (widget.overlayMarkers?.value ?? const <MapOverlayMarker>[])
        .take(1000)
        .map(
          (overlay) => MapGeoJsonPoint(
            id: overlay.id,
            point: overlay.point,
            properties: {
              'label': overlay.label,
              'color': _hexColor(overlay.color),
            },
          ),
        ),
  );

  void _onMapLibreFeatureTapped(
    math.Point<double> point,
    ml.LatLng coordinates,
    String id,
    String layerId,
    ml.Annotation? annotation,
  ) {
    if (layerId != 'ride-relay-overlay-circles' &&
        layerId != 'ride-relay-waypoint-circles') {
      return;
    }
    final overlay = (widget.overlayMarkers?.value ?? const <MapOverlayMarker>[])
        .where((item) => item.id == id)
        .firstOrNull;
    final waypoint = _route?.waypoints.indexed
        .where((entry) => 'waypoint-${entry.$1}' == id)
        .map((entry) => entry.$2)
        .firstOrNull;
    final label = overlay?.label ?? waypoint?.name ?? 'GPX waypoint';
    _showMessage(label);
  }

  Future<void> _importGpx() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final route = await widget.routeImporter.importFromPicker();
      if (route == null) return;
      await _activateRoute(route);
    } on FormatException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Could not import GPX: $error');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _loadDemoRoute() async {
    try {
      final loader = widget.demoRouteLoader ?? _loadBundledDemoRoute;
      await _activateRoute(await loader());
    } catch (error) {
      _showMessage('Could not load demo route: $error');
    }
  }

  Future<ImportedRoute> _loadBundledDemoRoute() async {
    final data = await rootBundle.load('assets/demo_route.gpx');
    return const GpxParser().parse(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      routeId: const Uuid().v4(),
      sourceFileName: 'demo_route.gpx',
      importedAt: DateTime.now(),
    );
  }

  Future<void> _activateRoute(ImportedRoute route) async {
    await widget.routeStore.saveActiveRoute(route);
    if (!mounted) return;
    setState(() => _route = route);
    await _syncMapLibreSources();
    _fitRoute();
    widget.onRouteChanged?.call(route);
    _showMessage(
      '${route.name}: ${route.pathPointCount} route points stored offline.',
    );
  }

  Future<void> _downloadOfflineMap() async {
    final route = _route;
    if (route == null || !_basemap.canDownloadOffline) return;
    final cancellation = TileDownloadCancellationToken();
    setState(() {
      _downloadCancellation = cancellation;
      _downloadProgress = const TileDownloadProgress(
        completedTiles: 0,
        totalTiles: 1,
        downloadedBytes: 0,
      );
    });
    try {
      final summary = _basemap.usesMapLibre
          ? await _mapLibreOfflineManager.downloadRouteRegion(
              route,
              cancellationToken: cancellation,
              onProgress: (progress) {
                if (mounted) setState(() => _downloadProgress = progress);
              },
            )
          : await widget.offlineTileCache.downloadRouteCorridor(
              route,
              cancellationToken: cancellation,
              onProgress: (progress) {
                if (mounted) setState(() => _downloadProgress = progress);
              },
            );
      _showMessage(
        summary.cancelled
            ? 'Offline map download cancelled.'
            : _basemap.usesMapLibre
            ? '${summary.totalTiles} offline map resources ready.'
            : '${summary.totalTiles} offline tiles ready (${summary.reusedTiles} already cached).',
      );
      if (mounted) setState(() {});
    } catch (error) {
      _showMessage('Offline map download stopped: $error');
    } finally {
      if (mounted) {
        setState(() {
          _downloadCancellation = null;
          _downloadProgress = null;
        });
      }
    }
  }

  Future<void> _openNavigationExport() async {
    final route = _route;
    if (route == null) return;
    final target = await NavigationExportSheet.show(context);
    if (target == null || !mounted) return;
    setState(() => _exporting = true);
    try {
      final renderObject = context.findRenderObject();
      final origin = renderObject is RenderBox && renderObject.hasSize
          ? renderObject.localToGlobal(Offset.zero) & renderObject.size
          : null;
      final result =
          await (widget.navigationExportCoordinator ??
                  const NavigationExportCoordinator())
              .export(target, route, sharePositionOrigin: origin);
      _showMessage(result.message);
    } catch (error) {
      _showMessage('Could not export route: $error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _fitRoute() {
    final routePoints = _route?.allPoints.toList(growable: false) ?? [];
    if (_basemap.usesMapLibre) {
      final controller = _mapLibreController;
      if (controller == null || routePoints.isEmpty) return;
      if (routePoints.length == 1) {
        unawaited(
          controller.animateCamera(
            ml.CameraUpdate.newLatLngZoom(
              ml.LatLng(
                routePoints.single.latitude,
                routePoints.single.longitude,
              ),
              14,
            ),
          ),
        );
        return;
      }
      final bounds = _mapLibreBounds(routePoints);
      unawaited(
        controller.animateCamera(
          ml.CameraUpdate.newLatLngBounds(
            bounds,
            left: 42,
            top: 42,
            right: 42,
            bottom: 42,
          ),
        ),
      );
      return;
    }
    final points = routePoints.map(_latLng).toList(growable: false);
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.single, 14);
    } else {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(42),
        ),
      );
    }
  }

  Future<void> _handleMenuAction(_MapAction action) async {
    switch (action) {
      case _MapAction.importGpx:
        await _importGpx();
      case _MapAction.loadDemo:
        await _loadDemoRoute();
      case _MapAction.downloadOffline:
        await _downloadOfflineMap();
      case _MapAction.removeRoute:
        await widget.routeStore.clearActiveRoute();
        if (mounted) {
          setState(() => _route = null);
          await _syncMapLibreSources();
          widget.onRouteChanged?.call(null);
        }
      case _MapAction.clearOfflineTiles:
        await _mapLibreOfflineManager.clearAll();
        await widget.offlineTileCache.clearAll();
        _showMessage('Offline map data cleared.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _MapAction {
  importGpx,
  loadDemo,
  downloadOffline,
  removeRoute,
  clearOfflineTiles,
}

/// Neutral presentation model for hazards, group riders, markers, or other
/// feature-owned map overlays. Callers retain ownership of their domain models.
class MapOverlayMarker {
  const MapOverlayMarker({
    required this.id,
    required this.point,
    required this.label,
    this.icon = Icons.warning_amber_rounded,
    this.color = const Color(0xFFFFC857),
  });

  final String id;
  final GeoPoint point;
  final String label;
  final IconData icon;
  final Color color;
}

LatLng _latLng(GeoPoint point) => LatLng(point.latitude, point.longitude);

ml.LatLngBounds _mapLibreBounds(List<GeoPoint> points) {
  var south = points.first.latitude;
  var north = points.first.latitude;
  var west = points.first.longitude;
  var east = points.first.longitude;
  for (final point in points.skip(1)) {
    south = math.min(south, point.latitude);
    north = math.max(north, point.latitude);
    west = math.min(west, point.longitude);
    east = math.max(east, point.longitude);
  }
  return ml.LatLngBounds(
    southwest: ml.LatLng(south, west),
    northeast: ml.LatLng(north, east),
  );
}

String _hexColor(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

class _EmptyRoutePrompt extends StatelessWidget {
  const _EmptyRoutePrompt({
    required this.importing,
    required this.onImport,
    required this.onLoadDemo,
  });

  final bool importing;
  final VoidCallback onImport;
  final VoidCallback onLoadDemo;

  @override
  Widget build(BuildContext context) => Center(
    child: Card(
      margin: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose a route',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Import a GPX file, or use the demo route to try the map.',
                style: TextStyle(color: Color(0xFF98A3B1)),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: importing ? null : onImport,
                icon: importing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: const Text('Import GPX'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onLoadDemo,
                child: const Text('Use demo route'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.progress, required this.onCancel});

  final TileDownloadProgress progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
    child: Row(
      children: [
        Expanded(child: LinearProgressIndicator(value: progress.fraction)),
        const SizedBox(width: 10),
        Text('${progress.completedTiles}/${progress.totalTiles}'),
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
      ],
    ),
  );
}

class _CurrentPositionMarker extends StatelessWidget {
  const _CurrentPositionMarker();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF4AA3FF),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5)],
    ),
  );
}

class _RouteOnlyBadge extends StatelessWidget {
  const _RouteOnlyBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xDD171D25),
      borderRadius: BorderRadius.circular(9),
    ),
    child: const Text('ROUTE-ONLY OFFLINE MAP', style: TextStyle(fontSize: 10)),
  );
}

class _MapAttributionBadge extends StatelessWidget {
  const _MapAttributionBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 260),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xCC171D25),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: const TextStyle(fontSize: 9)),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Could not read the saved route: $error'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
