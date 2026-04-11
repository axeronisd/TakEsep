import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../theme/akjol_theme.dart';
import '../../providers/location_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _supabase = Supabase.instance.client;
  final _mapController = MapController();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _addresses = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _loading = true;

  LatLng? _pickedPoint;


  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _loadStores() async {
    try {
      final data = await _supabase
          .from('delivery_settings')
          .select('*, warehouses(name, address)')
          .eq('is_active', true);

      if (!mounted) return;
      setState(() {
        _stores = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });

      // Загружаем адреса рядом
      _loadNearbyAddresses();
    } catch (e) {
      debugPrint('⚠️ Map stores: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadNearbyAddresses() async {
    final loc = ref.read(locationProvider);
    if (loc.lat == null || loc.lng == null) return;

    try {
      final data = await _supabase.rpc('nearby_addresses', params: {
        'p_lat': loc.lat,
        'p_lng': loc.lng,
        'p_radius_m': 2000,
      });
      if (!mounted) return;
      setState(() {
        _addresses = List<Map<String, dynamic>>.from(data ?? []);
      });
    } catch (e) {
      debugPrint('⚠️ Addresses: $e');
    }
  }

  Future<void> _searchAddresses(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      // Поиск по адресам
      final addrData = await _supabase
          .from('addresses')
          .select()
          .eq('verified', true)
          .or('street.ilike.%$query%,building_name.ilike.%$query%,house_number.ilike.%$query%')
          .limit(5);

      // Поиск по магазинам/складам
      final storeData = await _supabase
          .from('delivery_settings')
          .select('*, warehouses(name, address)')
          .eq('is_active', true)
          .limit(20);

      // Фильтруем магазины локально по имени
      final q = query.toLowerCase();
      final matchedStores = (storeData as List).where((s) {
        final name = (s['warehouses']?['name'] as String? ?? '').toLowerCase();
        final addr = (s['warehouses']?['address'] as String? ?? '').toLowerCase();
        return name.contains(q) || addr.contains(q);
      }).map((s) => {
        ...Map<String, dynamic>.from(s),
        '_type': 'store',
        '_name': s['warehouses']?['name'] ?? 'Магазин',
        '_address': s['warehouses']?['address'] ?? '',
      }).toList();

      // Объединяем: сначала магазины, потом адреса
      final combined = <Map<String, dynamic>>[
        ...matchedStores.take(5),
        ...List<Map<String, dynamic>>.from(addrData).map((a) => {...a, '_type': 'address'}),
      ];

      if (!mounted) return;
      setState(() {
        _searchResults = combined.take(10).toList();
      });
    } catch (e) {
      debugPrint('⚠️ Search: $e');
    }
  }

  void _goToAddress(Map<String, dynamic> addr) {
    double? lat, lng;
    if (addr['_type'] == 'store') {
      lat = (addr['latitude'] as num?)?.toDouble();
      lng = (addr['longitude'] as num?)?.toDouble();
    } else {
      lat = (addr['lat'] as num?)?.toDouble();
      lng = (addr['lng'] as num?)?.toDouble();
    }
    if (lat != null && lng != null) {
      _mapController.move(LatLng(lat, lng), 17);
    }
    setState(() {
      _searchResults = [];
      _searchController.clear();
    });
  }

  Future<void> _handleMapTap(TapPosition tapPosition, LatLng point) async {
    setState(() {
      _pickedPoint = point;

    });

    try {
      // Nominatim reverse geocoding — точный до номера дома для КР
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json'
        '&lat=${point.latitude}'
        '&lon=${point.longitude}'
        '&zoom=19'
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
          final road = addr['road'] ?? addr['pedestrian'] ?? addr['footway']
              ?? addr['path'] ?? addr['residential'] ?? addr['tertiary'] ?? '';
          final houseNumber = addr['house_number'] ?? '';
          final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? '';

          String street = road.toString();
          if (street.isNotEmpty && houseNumber.toString().isNotEmpty) {
            street = '$street, ${houseNumber}';
          }

          final parts = <String>[];
          if (street.isNotEmpty) parts.add(street);
          if (city.toString().isNotEmpty) parts.add(city.toString());

          final address = parts.isNotEmpty
              ? parts.join(', ')
              : data['display_name'] as String? ?? 'Неизвестный адрес';

          debugPrint('📍 Resolved address: $address');

        } else {
          // no address found
        }
      } else {
        // non-200 response
      }
    } catch (e) {
      debugPrint('⚠️ Nominatim tap error: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    final location = ref.watch(locationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Центр карты — текущее местоположение или Бишкек
    final center = (location.lat != null && location.lng != null)
        ? LatLng(location.lat!, location.lng!)
        : const LatLng(42.8746, 74.5698);

    return Scaffold(
      body: Stack(
        children: [
          // ── Карта ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14.0,
              minZoom: 4,
              maxZoom: 18,
              onTap: _handleMapTap,
            ),
            children: [
              // OSM тайлы
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.takesep.customer',
                maxZoom: 19,
                keepBuffer: 3,
                panBuffer: 1,
                tileSize: 256,
                evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
              ),

              // Точка пользователя
              if (location.lat != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(location.lat!, location.lng!),
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AkJolTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AkJolTheme.primary.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

              // Магазины — маркеры с логотипом
              if (!_loading)
                MarkerLayer(
                  markers: _stores.map((store) {
                    final lat = (store['latitude'] as num?)?.toDouble();
                    final lng = (store['longitude'] as num?)?.toDouble();
                    if (lat == null || lng == null) return null;
                    final logoUrl = store['logo_url'] as String?;

                    return Marker(
                      point: LatLng(lat, lng),
                      width: 48,
                      height: 48,
                      child: GestureDetector(
                        onTap: () => _showStoreSheet(context, store),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161B22) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AkJolTheme.primary, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: AkJolTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            image: logoUrl != null && logoUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(logoUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: logoUrl == null || logoUrl.isEmpty
                              ? const Icon(Icons.storefront_rounded, color: AkJolTheme.primary, size: 22)
                              : null,
                        ),
                      ),
                    );
                  }).whereType<Marker>().toList(),
                ),

              // Точка выбора адреса
              if (_pickedPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pickedPoint!,
                      width: 50,
                      height: 50,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.redAccent,
                        size: 40,
                      ),
                    ),
                  ],
                ),

              // Адреса (дома)
              if (_addresses.isNotEmpty)
                MarkerLayer(
                  markers: _addresses.map((addr) {
                    final lat = (addr['lat'] as num).toDouble();
                    final lng = (addr['lng'] as num).toDouble();
                    final house = addr['house_number'] as String? ?? '';
                    final street = addr['street'] as String? ?? '';
                    final label = house.isNotEmpty ? house : street;

                    return Marker(
                      point: LatLng(lat, lng),
                      width: 40,
                      height: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isDark ? const Color(0xFF21262D) : Colors.white).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF24292F),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),

          // ── Кнопка «Мое местоположение» ──
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton.small(
              heroTag: 'my_location',
              backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
              onPressed: () {
                if (location.lat != null) {
                  _mapController.move(
                    LatLng(location.lat!, location.lng!),
                    15,
                  );
                }
              },
              child: Icon(
                Icons.my_location_rounded,
                color: AkJolTheme.primary,
                size: 20,
              ),
            ),
          ),

          // ── Поиск (сверху) ──
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search bar (pill)
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161B22) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _searchAddresses,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Поиск адреса...',
                          hintStyle: TextStyle(
                            color: isDark ? const Color(0xFF6E7681) : const Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(Icons.search_rounded, color: AkJolTheme.primary, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded, size: 18, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280)),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchResults = []);
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    // Search results
                    if (_searchResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        constraints: const BoxConstraints(maxHeight: 280),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161B22) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ListView(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            children: _searchResults.map((addr) {
                              final isStore = addr['_type'] == 'store';
                              String title, sub;
                              IconData icon;

                              if (isStore) {
                                title = addr['_name'] ?? 'Магазин';
                                sub = addr['_address'] ?? '';
                                icon = Icons.storefront_rounded;
                              } else {
                                final street = addr['street'] ?? '';
                                final house = addr['house_number'] ?? '';
                                final bldg = addr['building_name'] ?? '';
                                title = bldg.isNotEmpty ? bldg : '$street $house';
                                sub = bldg.isNotEmpty ? '$street $house' : (addr['district'] ?? '');
                                icon = Icons.location_on_rounded;
                              }

                              return ListTile(
                                dense: true,
                                leading: Icon(icon, color: isStore ? const Color(0xFF2ECC71) : AkJolTheme.primary, size: 18),
                                title: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF111827))),
                                subtitle: sub.trim().isNotEmpty
                                    ? Text(sub, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280)))
                                    : null,
                                trailing: isStore
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('Магазин', style: TextStyle(fontSize: 9, color: Color(0xFF2ECC71), fontWeight: FontWeight.w700)),
                                      )
                                    : null,
                                onTap: () => _goToAddress(addr),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStoreSheet(BuildContext context, Map<String, dynamic> store) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = store['warehouses']?['name'] ?? 'Магазин';
    final address = store['warehouses']?['address'] ?? store['address'] ?? '';
    final desc = store['description'] as String? ?? '';
    final wId = store['warehouse_id'];
    final logoUrl = store['logo_url'] as String?;
    final bannerUrl = store['banner_url'] as String?;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Banner
          if (bannerUrl != null && bannerUrl.isNotEmpty)
            Container(
              height: 140,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: NetworkImage(bannerUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo + Name + Address
                Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: AkJolTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AkJolTheme.primary.withValues(alpha: 0.2)),
                        image: logoUrl != null && logoUrl.isNotEmpty
                            ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover)
                            : null,
                      ),
                      child: logoUrl == null || logoUrl.isEmpty
                          ? const Icon(Icons.storefront_rounded, color: AkJolTheme.primary, size: 28)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                            style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          if (address.isNotEmpty)
                            Text(address,
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Description
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(desc,
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey[700], height: 1.4),
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Info chips — транспорт
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: [
                    _infoChip('Электровелосипед • 100 сом', Colors.green),
                    _infoChip('Муравей • 150 сом', Colors.orange),
                  ],
                ),

                const SizedBox(height: 16),

                // Open store button
                SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/store/$wId');
                      },
                      icon: const Icon(Icons.storefront_rounded, size: 20),
                      label: const Text('Открыть магазин', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AkJolTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
