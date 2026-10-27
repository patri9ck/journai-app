// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../messages/app_localizations.dart';
import '../../model/poi.dart';
import '../../service/services.dart';

class FullMapPage extends StatefulWidget {
  final LatLng position;

  const FullMapPage({super.key, required this.position});

  @override
  State<FullMapPage> createState() => _FullMapPageState();
}

class _FullMapPageState extends State<FullMapPage> {
  List<Poi>? _pois;
  bool _failed = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadPois();
  }

  @override
  void didUpdateWidget(FullMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.position != widget.position) {
      _loadPois();
    }
  }

  Future<void> _loadPois() async {
    final generation = ++_loadGeneration;

    setState(() => _failed = false);

    final cachedPois = await overpassService.getCachedPois(
      widget.position.latitude,
      widget.position.longitude,
    );

    if (!mounted || generation != _loadGeneration) {
      return;
    }

    if (cachedPois.isNotEmpty) {
      setState(() => _pois = cachedPois);
    }

    final freshPois = await overpassService.getNearbyPois(
      widget.position.latitude,
      widget.position.longitude,
    );

    if (!mounted || generation != _loadGeneration) {
      return;
    }

    if (freshPois == null) {
      setState(() => _failed = _pois == null);

      return;
    }

    setState(() => _pois = freshPois);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final center = widget.position;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: appId,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.location_pin,
                      color: theme.colorScheme.primary,
                      size: 40,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  if (_pois != null)
                    ..._pois!.map(
                      (poi) => Marker(
                        point: LatLng(poi.latitude, poi.longitude),
                        width: 40,
                        height: 40,
                        child: _PoiMarker(poi: poi),
                      ),
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                elevation: 3,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: _PoiLegend(
                pois: _pois,
                failed: _failed,
                onRetry: _loadPois,
                localizations: localizations,
                theme: theme,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PoiMarker extends StatelessWidget {
  final Poi poi;

  const _PoiMarker({required this.poi});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (poi.type) {
      PoiType.hospital => (Icons.local_hospital, Colors.red.shade600),
      PoiType.pharmacy => (Icons.local_pharmacy, Colors.green.shade700),
      PoiType.police => (Icons.local_police, Colors.blue.shade800),
      PoiType.fireStation => (Icons.local_fire_department, Colors.orange.shade700),
      PoiType.doctor => (Icons.medical_services, Colors.teal.shade600),
    };

    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _PoiLegend extends StatelessWidget {
  final List<Poi>? pois;
  final bool failed;
  final VoidCallback onRetry;
  final AppLocalizations localizations;
  final ThemeData theme;

  const _PoiLegend({
    required this.pois,
    required this.failed,
    required this.onRetry,
    required this.localizations,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Container(
        key: const ValueKey('poi_load_failed'),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                localizations.fullMapPoisUnavailable,
                style: theme.textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(localizations.fullMapRetry),
            ),
          ],
        ),
      );
    }

    if (pois == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              localizations.fullMapLoadingPois,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    const types = PoiType.values;

    String labelFor(PoiType type) => switch (type) {
      PoiType.hospital => localizations.fullMapPoiHospital,
      PoiType.pharmacy => localizations.fullMapPoiPharmacy,
      PoiType.police => localizations.fullMapPoiPolice,
      PoiType.fireStation => localizations.fullMapPoiFireStation,
      PoiType.doctor => localizations.fullMapPoiDoctor,
    };

    Color colorFor(PoiType type) => switch (type) {
      PoiType.hospital => Colors.red.shade600,
      PoiType.pharmacy => Colors.green.shade600,
      PoiType.police => Colors.blue.shade700,
      PoiType.fireStation => Colors.orange.shade700,
      PoiType.doctor => Colors.teal.shade600,
    };

    IconData iconFor(PoiType type) => switch (type) {
      PoiType.hospital => Icons.local_hospital,
      PoiType.pharmacy => Icons.local_pharmacy,
      PoiType.police => Icons.local_police,
      PoiType.fireStation => Icons.local_fire_department,
      PoiType.doctor => Icons.medical_services,
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: types.map<Widget>((type) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: colorFor(type),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconFor(type), color: Colors.white, size: 12),
              ),
              const SizedBox(width: 6),
              Text(labelFor(type), style: theme.textTheme.labelSmall),
            ],
          );
        }).toList(),
      ),
    );
  }
}
