import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:takesep_design_system/takesep_design_system.dart';

/// A map-based location picker widget using flutter_map + CartoDB Dark tiles.
/// Reverse geocoding via free Nominatim (OpenStreetMap).
class MapLocationPicker extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;
  final ValueChanged<MapLocationResult> onLocationChanged;

  const MapLocationPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    required this.onLocationChanged,
  });

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class MapLocationResult {
  final double latitude;
  final double longitude;
  final String? address;

  const MapLocationResult({
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  late final MapController _mapController;
  LatLng _markerPosition = const LatLng(42.87, 74.59); // Bishkek default
  bool _hasMarker = false;
  bool _isGeocoding = false;
  bool _isLocating = false;
  String? _currentAddress;
  Timer? _debounce;

  // Search
  final TextEditingController _searchController = TextEditingController();
  List<_SearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _markerPosition = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _hasMarker = true;
      _currentAddress = widget.initialAddress;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _markerPosition = point;
      _hasMarker = true;
      _showSearchResults = false;
    });
    _reverseGeocode(point);
  }


  Future<void> _reverseGeocode(LatLng point) async {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isGeocoding = true);

      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?format=jsonv2&lat=${point.latitude}&lon=${point.longitude}'
          '&accept-language=ru&zoom=18',
        );
        final response = await http.get(url, headers: {
          'User-Agent': 'TakEsep-Warehouse/1.0',
        });

        if (response.statusCode == 200 && mounted) {
          final data = json.decode(response.body);
          final addr = data['display_name'] as String?;
          // Extract just the meaningful part (first 2-3 components)
          final parts = addr?.split(',').map((s) => s.trim()).toList() ?? [];
          final shortAddr = parts.take(3).join(', ');

          setState(() {
            _currentAddress = shortAddr.isNotEmpty ? shortAddr : null;
            _isGeocoding = false;
          });

          widget.onLocationChanged(MapLocationResult(
            latitude: point.latitude,
            longitude: point.longitude,
            address: _currentAddress,
          ));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isGeocoding = false);
          widget.onLocationChanged(MapLocationResult(
            latitude: point.latitude,
            longitude: point.longitude,
          ));
        }
      }
    });
  }

  Future<void> _goToMyLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showLocationError('GPS выключен. Включите геолокацию.');
        }
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          if (mounted) _showLocationError('Доступ к геолокации запрещён');
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          _showLocationError('Геолокация запрещена в настройках устройства');
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _markerPosition = point;
        _hasMarker = true;
      });
      _mapController.move(point, 17);
      _reverseGeocode(point);
    } catch (e) {
      if (mounted) {
        _showLocationError('Не удалось получить GPS: ${e.toString().length > 60 ? e.toString().substring(0, 60) : e}');
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showLocationError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.location_off, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ═══ SEARCH ═══
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchAddress(query.trim());
    });
  }

  Future<void> _searchAddress(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=jsonv2&q=${Uri.encodeQueryComponent(query)}'
        '&viewbox=74.3,43.1,74.9,42.6&bounded=1'
        '&accept-language=ru&limit=5',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'TakEsep-Warehouse/1.0',
      });

      if (response.statusCode == 200 && mounted) {
        final list = json.decode(response.body) as List;
        setState(() {
          _searchResults = list
              .map((item) => _SearchResult(
                    displayName: item['display_name'] as String? ?? '',
                    lat: double.tryParse(item['lat']?.toString() ?? '') ?? 0,
                    lon: double.tryParse(item['lon']?.toString() ?? '') ?? 0,
                  ))
              .toList();
          _showSearchResults = _searchResults.isNotEmpty;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(_SearchResult result) {
    final point = LatLng(result.lat, result.lon);
    setState(() {
      _markerPosition = point;
      _hasMarker = true;
      _showSearchResults = false;
      _searchController.text = '';
    });
    _mapController.move(point, 17);
    _reverseGeocode(point);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Map container
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: isMobile ? 260 : 320,
            child: Stack(
              children: [
                // ── Map ──
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _hasMarker
                        ? _markerPosition
                        : const LatLng(42.87, 74.59),
                    initialZoom: _hasMarker ? 16 : 13,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.takesep.warehouse',
                    ),
                    if (_hasMarker)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _markerPosition,
                            width: 40,
                            height: 50,
                            child: _buildMapPin(cs),
                          ),
                        ],
                      ),
                  ],
                ),

                // ── Desktop search overlay ──
                if (!isMobile)
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 60,
                    child: _buildSearchBar(cs),
                  ),

                // ── My location button ──
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Material(
                    color: cs.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                    elevation: 3,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _isLocating ? null : _goToMyLocation,
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: _isLocating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.my_location_rounded,
                                size: 20, color: AppColors.primary),
                      ),
                    ),
                  ),
                ),

                // ── Geocoding indicator ──
                if (_isGeocoding)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(
                            width: 12,
                            height: 12,
                            child:
                                CircularProgressIndicator(strokeWidth: 1.5)),
                        const SizedBox(width: 8),
                        Text('Определяю адрес...',
                            style: AppTypography.bodySmall
                                .copyWith(fontSize: 11)),
                      ]),
                    ),
                  ),

                // ── Hint overlay when no marker ──
                if (!_hasMarker)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 60,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Icon(Icons.touch_app_rounded,
                            size: 16,
                            color: AppColors.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Нажмите на карту, чтобы указать локацию склада',
                            style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── Mobile search (below map) ──
        if (isMobile) ...[
          const SizedBox(height: 10),
          _buildSearchBar(cs),
        ],
      ],
    );
  }

  Widget _buildMapPin(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.store_rounded, color: Colors.white, size: 16),
        ),
        CustomPaint(
          size: const Size(12, 10),
          painter: _PinTailPainter(AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildSearchBar(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onTap: () {
              if (_searchResults.isNotEmpty) {
                setState(() => _showSearchResults = true);
              }
            },
            style: AppTypography.bodySmall.copyWith(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Поиск адреса в Бишкеке...',
              hintStyle: AppTypography.bodySmall
                  .copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
              prefixIcon: Icon(Icons.search_rounded,
                  size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 1.5)),
                    )
                  : _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 16,
                              color: cs.onSurface.withValues(alpha: 0.4)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                              _showSearchResults = false;
                            });
                          },
                        )
                      : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
          ),
        ),

        // Search results dropdown
        if (_showSearchResults && _searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
              itemBuilder: (_, i) {
                final r = _searchResults[i];
                // Short display
                final parts = r.displayName.split(',');
                final title = parts.take(2).join(',').trim();
                final subtitle =
                    parts.length > 2 ? parts.skip(2).take(2).join(',').trim() : '';

                return ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  leading: Icon(Icons.location_on_rounded,
                      size: 18, color: AppColors.primary.withValues(alpha: 0.7)),
                  title: Text(title,
                      style: AppTypography.bodySmall
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  subtitle: subtitle.isNotEmpty
                      ? Text(subtitle,
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 10,
                            color: cs.onSurface.withValues(alpha: 0.4),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)
                      : null,
                  onTap: () => _selectSearchResult(r),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SearchResult {
  final String displayName;
  final double lat;
  final double lon;

  const _SearchResult({
    required this.displayName,
    required this.lat,
    required this.lon,
  });
}

/// Custom painter for the pin tail triangle
class _PinTailPainter extends CustomPainter {
  final Color color;
  _PinTailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
