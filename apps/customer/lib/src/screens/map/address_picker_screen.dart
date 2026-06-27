import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';
import '../../providers/location_provider.dart';

/// Full-screen address picker (Yandex Go style).
/// Pin stays fixed at center, user drags map underneath.
class AddressPickerScreen extends ConsumerStatefulWidget {
  final bool saveToLocationProvider;

  const AddressPickerScreen({
    super.key,
    this.saveToLocationProvider = true,
  });

  @override
  ConsumerState<AddressPickerScreen> createState() =>
      _AddressPickerScreenState();
}

class _AddressPickerScreenState extends ConsumerState<AddressPickerScreen> {
  final _mapController = MapController();
  final _addressController = TextEditingController();
  final _houseController = TextEditingController();
  final _entranceController = TextEditingController();

  String? _streetName;
  bool _isGeocoding = false;
  bool _showHint = true;
  bool _userEdited = false; // true = user typed in fields, don't overwrite
  Timer? _debounce;

  double _sheetHeight = 120.0; // Collapsed height by default
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();

    // Listen for manual edits
    _addressController.addListener(_onUserEdit);
    _houseController.addListener(_onUserEdit);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loc = ref.read(locationProvider);
      // Pre-fill from saved address
      if (loc.street != null && loc.street!.isNotEmpty) {
        // Temporarily disable edit tracking
        _addressController.removeListener(_onUserEdit);
        _houseController.removeListener(_onUserEdit);

        final parts = loc.street!.split(RegExp(r'\s+'));
        if (parts.length >= 2 && RegExp(r'^\d').hasMatch(parts.last)) {
          _addressController.text = parts.sublist(0, parts.length - 1).join(' ');
          _houseController.text = parts.last;
        } else {
          _addressController.text = loc.street!;
        }
        _streetName = _addressController.text;

        _addressController.addListener(_onUserEdit);
        _houseController.addListener(_onUserEdit);
      }



      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showHint = false);
      });
    });
  }

  void _onUserEdit() {
    // Mark as user-edited so geocoding won't overwrite
    _userEdited = true;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchDebounce?.cancel();
    _addressController.removeListener(_onUserEdit);
    _houseController.removeListener(_onUserEdit);
    _addressController.dispose();
    _houseController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════
  // Geocoding: Our Supabase → Nominatim fallback
  // Only runs on significant map movement
  // ═══════════════════════════════════════

  Future<void> _geocodeCenter(LatLng point) async {
    if (_userEdited) return;

    setState(() => _isGeocoding = true);

    _addressController.removeListener(_onUserEdit);
    _houseController.removeListener(_onUserEdit);

    // 1. Search our DB (wide radius for street name)
    final found = await _trySupabaseGeocode(point);

    // 2. Fallback to Nominatim — but then check for street corrections
    if (!found && mounted) {
      await _tryNominatimGeocode(point);

      // After Nominatim fills street, check if we have a correction for it
      if (mounted && _addressController.text.isNotEmpty) {
        await _checkStreetCorrection(point, _addressController.text);
      }
    }

    _addressController.addListener(_onUserEdit);
    _houseController.addListener(_onUserEdit);

    if (mounted) setState(() => _isGeocoding = false);
  }

  /// Search our DB: 300m for street name, 30m for house number
  Future<bool> _trySupabaseGeocode(LatLng point) async {
    try {
      final supabase = Supabase.instance.client;
      // Wide radius ~300m to catch whole street
      const delta = 0.003;
      final data = await supabase
          .from('addresses')
          .select()
          .gte('lat', point.latitude - delta)
          .lte('lat', point.latitude + delta)
          .gte('lng', point.longitude - delta)
          .lte('lng', point.longitude + delta)
          .order('verified', ascending: false)
          .limit(50);

      if (!mounted) return true;
      final results = List<Map<String, dynamic>>.from(data);

      if (results.isEmpty) return false;

      // Find closest address for house number (within 30m)
      Map<String, dynamic>? exactMatch;
      double exactDist = double.infinity;

      // Find closest address for street name (any within 300m)
      Map<String, dynamic>? streetMatch;
      double streetDist = double.infinity;

      for (final r in results) {
        final rLat = (r['lat'] as num).toDouble();
        final rLng = (r['lng'] as num).toDouble();
        final d = _distanceMeters(point.latitude, point.longitude, rLat, rLng);

        if (d < streetDist) {
          streetDist = d;
          streetMatch = r;
        }
        if (d < 60 && d < exactDist) {
          exactDist = d;
          exactMatch = r;
        }
      }

      // Use street name from nearest address in our DB
      if (streetMatch != null && streetDist < 300) {
        final street = streetMatch['street'] ?? '';
        if (street.isNotEmpty) {
          _addressController.text = street;
          _streetName = street;

          // Only fill house number from very close match
          if (exactMatch != null) {
            _houseController.text = exactMatch['house_number'] ?? '';
            debugPrint('🏠 DB exact: $street ${exactMatch['house_number']} (${exactDist.toStringAsFixed(0)}m)');
          } else {
            debugPrint('🏠 DB street: $street (${streetDist.toStringAsFixed(0)}m, no house match)');
          }
          return true;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Supabase geocode: $e');
    }
    return false;
  }

  /// Check if someone corrected the street name Nominatim returned
  Future<void> _checkStreetCorrection(LatLng point, String nominatimStreet) async {
    try {
      final supabase = Supabase.instance.client;
      // Search nearby for addresses with DIFFERENT street name
      const delta = 0.003;
      final data = await supabase
          .from('addresses')
          .select('street')
          .gte('lat', point.latitude - delta)
          .lte('lat', point.latitude + delta)
          .gte('lng', point.longitude - delta)
          .lte('lng', point.longitude + delta)
          .limit(10);

      final results = List<Map<String, dynamic>>.from(data);

      // Find most common corrected street name nearby
      final streetCounts = <String, int>{};
      for (final r in results) {
        final s = r['street'] as String? ?? '';
        if (s.isNotEmpty && s != nominatimStreet) {
          streetCounts[s] = (streetCounts[s] ?? 0) + 1;
        }
      }

      if (streetCounts.isNotEmpty) {
        // Use the most popular corrected name
        final corrected = streetCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
        _addressController.text = corrected;
        _streetName = corrected;
        debugPrint('🔄 Street corrected: $nominatimStreet → $corrected');
      }
    } catch (e) {
      debugPrint('⚠️ Street correction check: $e');
    }
  }




  /// Nominatim fallback
  Future<void> _tryNominatimGeocode(LatLng point) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json'
        '&lat=${point.latitude}'
        '&lon=${point.longitude}'
        '&zoom=18'
        '&addressdetails=1'
        '&accept-language=ru,ky',
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'AkJol-SuperApp/1.0',
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addr = data['address'] as Map<String, dynamic>?;

        if (addr != null) {
          final road = addr['road'] ??
              addr['pedestrian'] ??
              addr['footway'] ??
              addr['path'] ??
              addr['residential'] ??
              addr['tertiary'] ??
              addr['secondary'] ??
              '';
          final houseNumber = (addr['house_number'] ?? '').toString();

          _streetName = road.toString();
          _addressController.text = _streetName ?? '';

          if (houseNumber.isNotEmpty) {
            _houseController.text = houseNumber;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Nominatim: $e');
    }
  }

  /// Distance in meters
  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRad(double deg) => deg * math.pi / 180;

  // ═══════════════════════════════════════
  // Map interaction
  // ═══════════════════════════════════════

  void _onMapMove() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      final center = _mapController.camera.center;

      _userEdited = false;
      _geocodeCenter(center);
    });
  }

  String get _fullAddress {
    final street = _addressController.text.trim();
    final house = _houseController.text.trim();
    if (street.isEmpty) return '';
    return house.isNotEmpty ? '$street $house' : street;
  }

  Future<void> _confirmAddress() async {
    final address = _fullAddress;
    if (address.isEmpty) return;

    final center = _mapController.camera.center;

    // Save to our Supabase as pending (admin will verify)
    await _saveToSupabase(
      street: _addressController.text.trim(),
      houseNumber: _houseController.text.trim(),
      lat: center.latitude,
      lng: center.longitude,
    );

    if (!mounted) return;

    if (widget.saveToLocationProvider) {
      ref.read(locationProvider.notifier).setManualAddress(
            address,
            center.latitude,
            center.longitude,
          );
    }

    Navigator.of(context).pop({
      'address': address,
      'latitude': center.latitude,
      'longitude': center.longitude,
    });
  }

  void _onAddressSearchChanged(String val) {
    _searchDebounce?.cancel();
    if (val.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _executeAddressSearch(val.trim());
    });
  }

  Future<void> _executeAddressSearch(String query) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=json'
        '&q=$query'
        '&countrycodes=kg'
        '&limit=5'
        '&addressdetails=1'
        '&accept-language=ru,ky',
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'AkJol-SuperApp/1.0',
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          _searchResults = data.map((item) {
            final addr = item['address'] as Map<String, dynamic>? ?? {};
            final road = addr['road'] ?? addr['pedestrian'] ?? addr['footway']
                ?? addr['path'] ?? addr['residential'] ?? addr['tertiary'] ?? addr['secondary'] ?? '';
            final houseNumber = (addr['house_number'] ?? '').toString();
            final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? '';

            String street = road.toString();
            String fullLabel = street;
            if (houseNumber.isNotEmpty) {
              fullLabel = '$street, $houseNumber';
            }
            if (city.toString().isNotEmpty) {
              fullLabel = '$fullLabel, $city';
            } else {
              fullLabel = '$fullLabel, ${item['display_name']}';
            }

            return {
              'display_name': item['display_name'],
              'street': street,
              'house_number': houseNumber,
              'city': city,
              'lat': double.tryParse(item['lat']?.toString() ?? '') ?? 0.0,
              'lng': double.tryParse(item['lon']?.toString() ?? '') ?? 0.0,
              'full_label': fullLabel,
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('⚠️ Autocomplete Nominatim: $e');
    }
  }

  void _onMapTap(LatLng point) {
    _mapController.move(point, _mapController.camera.zoom);
    _onMapMove();
  }

  /// Save/update address in Supabase (pending for admin review)
  Future<void> _saveToSupabase({
    required String street,
    required String houseNumber,
    required double lat,
    required double lng,
  }) async {
    if (street.isEmpty) return;
    try {
      final supabase = Supabase.instance.client;

      // Find ANY existing address nearby (within ~30m)
      const delta = 0.0003;
      final existing = await supabase
          .from('addresses')
          .select('id, verified')
          .gte('lat', lat - delta)
          .lte('lat', lat + delta)
          .gte('lng', lng - delta)
          .lte('lng', lng + delta)
          .limit(1);

      final existingList = List<Map<String, dynamic>>.from(existing);

      if (existingList.isNotEmpty) {
        final entry = existingList.first;
        if (entry['verified'] == true) {
          // Already verified by admin — don't overwrite
          debugPrint('🏠 Verified address exists, keeping');
          return;
        }
        // UPDATE existing pending entry with corrected data
        await supabase.from('addresses').update({
          'street': street,
          'house_number': houseNumber.isEmpty ? null : houseNumber,
          'city': 'Бишкек',
          'lat': lat,
          'lng': lng,
        }).eq('id', entry['id']);
        debugPrint('✏️ Updated pending: $street $houseNumber');
      } else {
        // INSERT new pending address
        await supabase.from('addresses').insert({
          'street': street,
          'house_number': houseNumber.isEmpty ? null : houseNumber,
          'city': 'Бишкек',
          'lat': lat,
          'lng': lng,
          'verified': false,
        });
        debugPrint('✅ New pending: $street $houseNumber');
      }
    } catch (e) {
      debugPrint('⚠️ Save address: $e');
    }
  }

  // ═══════════════════════════════════════
  // Build
  // ═══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(locationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final initialCenter = (location.lat != null && location.lng != null)
        ? LatLng(location.lat!, location.lng!)
        : const LatLng(42.8746, 74.5698);

    final bg = isDark ? const Color(0xFF0D1117) : Colors.white;
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final fieldBg =
        isDark ? const Color(0xFF21262D) : const Color(0xFFF3F4F6);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ─── Map ───
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 18,
              minZoom: 4,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (tapPosition, point) => _onMapTap(point),
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) _onMapMove();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.takesep.customer',
                maxZoom: 19,
              ),
            ],
          ),

          // ─── Teardrop pin (кончик = центр карты) ───
          Center(
            child: Transform.translate(
              // Shift pin UP so the pointed tip sits at center
              offset: const Offset(0, -28),
              child: SizedBox(
                width: 44,
                height: 56,
                child: CustomPaint(
                  painter: _TeardropPinPainter(
                    color: AkJolTheme.primary,
                    borderColor: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // ─── Hint ───
          if (_showHint)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Text(
                      'Двигайте карту для выбора адреса',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ─── Back button ───
          Positioned(
            left: 16,
            bottom: _sheetHeight + 16,
            child: _circleButton(
              icon: Icons.arrow_back_rounded,
              isDark: isDark,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),

          // ─── My location button ───
          Positioned(
            right: 16,
            bottom: _sheetHeight + 16,
            child: _circleButton(
              icon: Icons.near_me_rounded,
              isDark: isDark,
              onTap: () async {
                final notifier = ref.read(locationProvider.notifier);
                await notifier.determinePosition();
                final updatedLoc = ref.read(locationProvider);
                if (updatedLoc.lat != null && updatedLoc.lng != null) {
                  final pt = LatLng(updatedLoc.lat!, updatedLoc.lng!);
                  _mapController.move(pt, 18);
                  _houseController.clear();
                  _geocodeCenter(pt);
                }
              },
            ),
          ),

          // ─── Search Suggestions Overlay ───
          if (_searchResults.isNotEmpty && _sheetHeight > 200)
            Positioned(
              left: 20,
              right: 20,
              bottom: _sheetHeight + 16,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
                    ),
                    itemBuilder: (context, idx) {
                      final item = _searchResults[idx];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.location_on_rounded,
                          color: AkJolTheme.primary,
                          size: 18,
                        ),
                        title: Text(
                          item['full_label'],
                          style: TextStyle(
                            fontSize: 13,
                            color: textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          _addressController.removeListener(_onUserEdit);
                          _houseController.removeListener(_onUserEdit);

                          setState(() {
                            _addressController.text = item['street'];
                            _houseController.text = item['house_number'];
                            _streetName = item['street'];
                            _searchResults = [];
                            _userEdited = true;
                          });

                          _mapController.move(LatLng(item['lat'], item['lng']), 18);

                          _addressController.addListener(_onUserEdit);
                          _houseController.addListener(_onUserEdit);
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

          // ─── Draggable Bottom panel ───
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                setState(() {
                  _sheetHeight -= details.delta.dy;
                  if (_sheetHeight < 120.0) _sheetHeight = 120.0;
                  if (_sheetHeight > 340.0) _sheetHeight = 340.0;
                });
              },
              onVerticalDragEnd: (details) {
                setState(() {
                  if (_sheetHeight < 220.0) {
                    _sheetHeight = 120.0;
                  } else {
                    _sheetHeight = 320.0;
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                height: _sheetHeight,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: textSecondary.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _sheetHeight = _sheetHeight < 200 ? 320.0 : 120.0;
                              });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Точка доставки',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: textPrimary,
                                        ),
                                      ),
                                      if (_sheetHeight < 200) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          _fullAddress.isNotEmpty ? _fullAddress : 'Перетащите карту или введите адрес',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(
                                  _sheetHeight < 200 ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                  color: textSecondary,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),

                          if (_sheetHeight >= 200) ...[
                            const SizedBox(height: 12),

                            // Street field
                            Container(
                              decoration: BoxDecoration(
                                color: fieldBg,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 14),
                                    child: Icon(
                                      Icons.location_on_rounded,
                                      color: AkJolTheme.primary,
                                      size: 22,
                                    ),
                                  ),
                                  Expanded(
                                    child: _isGeocoding
                                        ? Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 14),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: AkJolTheme.primary,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Определяем...',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : TextField(
                                            controller: _addressController,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: textPrimary,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Улица',
                                              hintStyle: TextStyle(
                                                color: textSecondary,
                                                fontWeight: FontWeight.w400,
                                              ),
                                              border: InputBorder.none,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 14),
                                            ),
                                            onChanged: _onAddressSearchChanged,
                                          ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 8),

                            // House + entrance
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: fieldBg,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: TextField(
                                      controller: _houseController,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Дом №',
                                        hintStyle: TextStyle(
                                          color: textSecondary,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.home_rounded,
                                          color: AkJolTheme.primary,
                                          size: 20,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 14),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: fieldBg,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: TextField(
                                      controller: _entranceController,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Подъезд',
                                        hintStyle: TextStyle(
                                          color: textSecondary,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // Confirm
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _fullAddress.isNotEmpty && !_isGeocoding
                                    ? _confirmAddress
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AkJolTheme.primary,
                                  disabledBackgroundColor:
                                      AkJolTheme.primary.withValues(alpha: 0.3),
                                  foregroundColor: Colors.white,
                                  disabledForegroundColor:
                                      Colors.white.withValues(alpha: 0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Готово',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: isDark ? Colors.white : const Color(0xFF374151),
          size: 22,
        ),
      ),
    );
  }
}

/// Teardrop-shaped map pin painter.
/// The very bottom pixel is the "point" — should align with map center.
class _TeardropPinPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _TeardropPinPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Circle radius (top part)
    final r = w * 0.42;
    final cy = r + 2; // Circle center Y

    final path = Path();

    // Start from bottom tip
    path.moveTo(cx, h);

    // Left curve up to circle
    path.quadraticBezierTo(cx - r * 0.3, cy + r * 1.1, cx - r, cy);

    // Top arc (circle)
    path.arcToPoint(
      Offset(cx + r, cy),
      radius: Radius.circular(r),
      largeArc: true,
    );

    // Right curve down to tip
    path.quadraticBezierTo(cx + r * 0.3, cy + r * 1.1, cx, h);

    path.close();

    // Shadow
    canvas.drawShadow(path, Colors.black, 6, true);

    // Border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Fill
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    // Inner white dot
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r * 0.35, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}