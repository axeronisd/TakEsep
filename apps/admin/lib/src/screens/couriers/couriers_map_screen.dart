import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

class CouriersMapScreen extends ConsumerStatefulWidget {
  const CouriersMapScreen({super.key});

  @override
  ConsumerState<CouriersMapScreen> createState() => _CouriersMapScreenState();
}

class _CouriersMapScreenState extends ConsumerState<CouriersMapScreen> {
  final _supabase = Supabase.instance.client;
  final _mapController = MapController();

  List<Map<String, dynamic>> _couriers = [];
  Map<String, dynamic>? _selectedCourier;
  bool _loading = true;
  String _search = '';
  String _filterStatus = 'online'; // 'all', 'online', 'offline'
  RealtimeChannel? _couriersChannel;

  @override
  void initState() {
    super.initState();
    _subscribeCouriers();
  }

  @override
  void dispose() {
    _couriersChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadCouriers() async {
    try {
      final data = await _supabase
          .from('couriers')
          .select()
          .order('name');
      if (!mounted) return;
      setState(() {
        _couriers = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('⚠️ Load couriers error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeCouriers() {
    _loadCouriers();

    _couriersChannel = _supabase.channel('couriers_realtime')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'couriers',
        callback: (payload) {
          if (!mounted) return;
          final eventType = payload.eventType;
          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;

          setState(() {
            if (eventType == PostgresChangeEvent.insert) {
              _couriers.insert(0, newRecord);
            } else if (eventType == PostgresChangeEvent.update) {
              final idx = _couriers.indexWhere((c) => c['id'] == newRecord['id']);
              if (idx != -1) {
                _couriers[idx] = newRecord;
                if (_selectedCourier != null && _selectedCourier!['id'] == newRecord['id']) {
                  _selectedCourier = newRecord;
                }
              } else {
                _couriers.add(newRecord);
              }
            } else if (eventType == PostgresChangeEvent.delete) {
              _couriers.removeWhere((c) => c['id'] == oldRecord['id']);
              if (_selectedCourier != null && _selectedCourier!['id'] == oldRecord['id']) {
                _selectedCourier = null;
              }
            }
          });
        },
      )
      ..subscribe();
  }

  List<Map<String, dynamic>> get _filteredCouriers {
    var list = _couriers;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((c) {
        final name = (c['name'] as String? ?? '').toLowerCase();
        final phone = (c['phone'] as String? ?? '').toLowerCase();
        return name.contains(q) || phone.contains(q);
      }).toList();
    }

    if (_filterStatus == 'online') {
      list = list.where((c) => c['is_online'] == true).toList();
    } else if (_filterStatus == 'offline') {
      list = list.where((c) => c['is_online'] != true).toList();
    }
    return list;
  }

  int get _onlineCount => _couriers.where((c) => c['is_online'] == true).length;
  int get _offlineCount => _couriers.where((c) => c['is_online'] != true).length;

  void _selectCourier(Map<String, dynamic> courier) {
    setState(() {
      _selectedCourier = courier;
    });

    final lat = (courier['current_lat'] as num?)?.toDouble();
    final lng = (courier['current_lng'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      _mapController.move(LatLng(lat, lng), 16);
    }
  }

  IconData _getTransportIcon(String? type) {
    switch (type) {
      case 'bicycle':
        return Icons.electric_bike_rounded;
      case 'scooter':
      case 'motorcycle':
        return Icons.two_wheeler_rounded;
      case 'car':
        return Icons.directions_car_rounded;
      default:
        return Icons.person_pin_circle_rounded;
    }
  }

  String _getTransportLabel(String? type) {
    switch (type) {
      case 'bicycle':
        return 'Электровелосипед';
      case 'scooter':
        return 'Электромуравей';
      case 'car':
        return 'Машина';
      default:
        return 'Пешком';
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 900;

    if (isMobile) return _buildMobileLayout();
    return _buildDesktopLayout();
  }

  Widget _buildMobileLayout() {
    const cardBg = AppColors.darkSurface;
    const accent = AppColors.primaryLight;
    final filtered = _filteredCouriers;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(42.8746, 74.5698),
              initialZoom: 14,
              minZoom: 4,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.takesep.admin',
                maxZoom: 19,
              ),
              _buildMarkerLayer(),
            ],
          ),
          // Top bar
          Positioned(
            top: 8, left: 8, right: 8,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cardBg.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_rounded, color: accent, size: 20),
                    const SizedBox(width: 8),
                    const Text('Карта курьеров', style: TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 10),
                    _badge('$_onlineCount', AppColors.successLight),
                    const SizedBox(width: 6),
                    _badge('$_offlineCount', Colors.grey),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
                      onPressed: _loadCouriers,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom sheet details or courier list
          if (_selectedCourier != null)
            Positioned(
              left: 12, right: 12, bottom: 20,
              child: _buildCourierDetailCard(_selectedCourier!),
            )
          else
            DraggableScrollableSheet(
              initialChildSize: 0.12, minChildSize: 0.08, maxChildSize: 0.65,
              builder: (context, sc) {
                return Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15)],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          controller: sc,
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            return _buildCourierListTile(c);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    const bg = AppColors.darkBackground;
    const cardBg = AppColors.darkSurface;
    const accent = AppColors.primaryLight;
    final filtered = _filteredCouriers;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              children: [
                const Icon(Icons.local_shipping_rounded, color: AppColors.primaryLight, size: 26),
                const SizedBox(width: 10),
                const Text('Мониторинг курьеров', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(width: 16),
                _badge('$_onlineCount В сети', AppColors.successLight),
                const SizedBox(width: 8),
                _badge('$_offlineCount Не в сети', Colors.grey),
                const Spacer(),
                IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20), tooltip: 'Обновить', onPressed: _loadCouriers),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // Side Panel
                SizedBox(
                  width: 340,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Column(children: [
                          TextField(
                            onChanged: (v) => setState(() => _search = v),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Поиск по имени или телефону...', hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                              prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 18),
                              filled: true, fillColor: cardBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            _filterTab('В сети', 'online', _onlineCount),
                            const SizedBox(width: 6),
                            _filterTab('Не в сети', 'offline', _offlineCount),
                            const SizedBox(width: 6),
                            _filterTab('Все', 'all', _couriers.length),
                          ]),
                        ]),
                      ),
                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator(color: accent))
                            : filtered.isEmpty
                                ? Center(child: Text('Нет подходящих курьеров', style: TextStyle(color: Colors.grey[600])))
                                : ListView.builder(
                                    itemCount: filtered.length,
                                    itemBuilder: (context, i) {
                                      final c = filtered[i];
                                      return _buildCourierListTile(c);
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
                // Map Area
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(0, 0, 24, 24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.darkBorder),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: FlutterMap(
                            mapController: _mapController,
                            options: const MapOptions(
                              initialCenter: LatLng(42.8746, 74.5698),
                              initialZoom: 13.0,
                              minZoom: 4,
                              maxZoom: 19,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.takesep.admin',
                                maxZoom: 19,
                              ),
                              _buildMarkerLayer(),
                            ],
                          ),
                        ),
                      ),
                      if (_selectedCourier != null)
                        Positioned(
                          right: 40, bottom: 40,
                          width: 320,
                          child: _buildCourierDetailCard(_selectedCourier!),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourierListTile(Map<String, dynamic> c) {
    final isOnline = c['is_online'] == true;
    final isSelected = _selectedCourier?['id'] == c['id'];
    final lat = c['current_lat'];
    final lng = c['current_lng'];
    final hasLocation = lat != null && lng != null;

    return ListTile(
      onTap: () => _selectCourier(c),
      selected: isSelected,
      selectedTileColor: AppColors.darkSurfaceVariant.withValues(alpha: 0.5),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: isOnline ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(_getTransportIcon(c['transport_type']),
            color: isOnline ? AppColors.successLight : Colors.grey, size: 18),
      ),
      title: Text(c['name'] ?? 'Без имени',
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      subtitle: Text(c['phone'] ?? '—',
          style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hasLocation)
            const Tooltip(
              message: 'Геолокация недоступна',
              child: Icon(Icons.location_off_rounded, color: Colors.redAccent, size: 14),
            )
          else
            const Icon(Icons.location_on_rounded, color: AppColors.successLight, size: 14),
          const SizedBox(width: 8),
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourierDetailCard(Map<String, dynamic> c) {
    final isOnline = c['is_online'] == true;
    final updatedTime = c['location_updated_at'] != null
        ? DateTime.tryParse(c['location_updated_at'])
        : null;

    String locationStatus = 'Координаты недоступны';
    if (c['current_lat'] != null && c['current_lng'] != null) {
      if (updatedTime != null) {
        final diff = DateTime.now().difference(updatedTime);
        if (diff.inMinutes < 1) {
          locationStatus = 'Обновлено только что';
        } else {
          locationStatus = 'Обновлено ${diff.inMinutes} мин. назад';
        }
      } else {
        locationStatus = 'Координаты получены';
      }
    }

    return Card(
      color: AppColors.darkSurface,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['name'] ?? 'Без имени', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(c['phone'] ?? '—', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                  onPressed: () => setState(() => _selectedCourier = null),
                ),
              ],
            ),
            const Divider(color: AppColors.darkBorder, height: 20),
            Row(
              children: [
                Icon(_getTransportIcon(c['transport_type']), color: AppColors.primaryLight, size: 18),
                const SizedBox(width: 8),
                Text(_getTransportLabel(c['transport_type']), style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.circle, color: isOnline ? Colors.green : Colors.grey, size: 10),
                const SizedBox(width: 8),
                Text(isOnline ? 'В сети (Свободен)' : 'Не в сети', style: TextStyle(color: isOnline ? Colors.green : Colors.grey, fontSize: 13)),
              ],
            ),
            if (c['bank_balance'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Text('Баланс: ${c['bank_balance']} сом', style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(locationStatus, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkerLayer() {
    final markers = _filteredCouriers.map((c) {
      final lat = (c['current_lat'] as num?)?.toDouble();
      final lng = (c['current_lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      final isOnline = c['is_online'] == true;
      final isSelected = _selectedCourier?['id'] == c['id'];

      return Marker(
        point: LatLng(lat, lng),
        width: isSelected ? 48 : 40,
        height: isSelected ? 48 : 40,
        child: GestureDetector(
          onTap: () => _selectCourier(c),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple animation look
              if (isSelected)
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.35),
                  ),
                ),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: (isOnline ? Colors.green : Colors.grey).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(_getTransportIcon(c['transport_type']), color: Colors.white, size: 18),
              ),
              // Direction/Status dot
              Positioned(
                right: 0, top: 0,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).whereType<Marker>().toList();

    return MarkerLayer(markers: markers);
  }

  Widget _badge(String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(count, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _filterTab(String label, String status, int count) {
    final isSelected = _filterStatus == status;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filterStatus = status),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.darkSurfaceVariant : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppColors.darkBorder : Colors.transparent),
          ),
          child: Text(
            '$label ($count)',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.darkTextSecondary,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
