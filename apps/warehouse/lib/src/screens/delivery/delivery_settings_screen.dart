import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../utils/snackbar_helper.dart';
import '../../providers/auth_providers.dart';

class DeliverySettingsScreen extends ConsumerStatefulWidget {
  final String warehouseId;
  const DeliverySettingsScreen({super.key, required this.warehouseId});

  @override
  ConsumerState<DeliverySettingsScreen> createState() => _DeliverySettingsScreenState();
}

class _DeliverySettingsScreenState extends ConsumerState<DeliverySettingsScreen> {
  final _supabase = Supabase.instance.client;

  final _addressController = TextEditingController();
  final _descController = TextEditingController();
  bool _isActive = false;
  bool _loading = true;
  bool _saving = false;
  bool _detectingGeo = false;
  String? _settingsId;
  String? _addressStatus;
  bool _isEditingAddress = false;
  LatLng? _pendingLocation;

  final MapController _zoneMapController = MapController();
  LatLng _warehouseLocation = const LatLng(42.8746, 74.5698);
  double _radiusKm = 3.0;

  List<Map<String, dynamic>> _ecosystemZones = [];
  bool _loadingEco = true;
  String? _errorLoadingEco;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadEcosystemZones();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadEcosystemZones() async {
    try {
      final data = await _supabase
          .from('ecosystem_zones')
          .select()
          .eq('is_active', true);
      setState(() {
        _ecosystemZones = List<Map<String, dynamic>>.from(data);
        _loadingEco = false;
        _errorLoadingEco = null;
      });
    } catch (e) {
      debugPrint('Error loading ecosystem zones in settings: $e');
      setState(() {
        _errorLoadingEco = e.toString();
        _loadingEco = false;
      });
    }
  }

  // Ecosystem validation checks removed as stores can place their coordinate anywhere.

  String get _warehouseId => widget.warehouseId;

  Future<void> _loadSettings() async {
    try {
      final data = await _supabase
          .from('delivery_settings')
          .select('*')
          .eq('warehouse_id', _warehouseId)
          .maybeSingle();

      if (data != null) {
        setState(() {
          _settingsId = data['id'];
          _isActive = data['is_active'] ?? false;
          _descController.text = data['description'] ?? '';
          _radiusKm = (data['delivery_radius_km'] ?? 3.0).toDouble();
          final lat = data['latitude'];
          final lng = data['longitude'];
          if (lat != null && lng != null) {
            _warehouseLocation = LatLng((lat as num).toDouble(), (lng as num).toDouble());
          }
        });
      }

      // Always fetch base address from warehouse
      final wh = await _supabase.from('warehouses').select('address, latitude, longitude').eq('id', _warehouseId).maybeSingle();
      if (wh != null) {
        setState(() {
          _addressController.text = wh['address'] ?? '';
          final wLat = wh['latitude'];
          final wLng = wh['longitude'];
          if (wLat != null && wLng != null) {
            _warehouseLocation = LatLng((wLat as num).toDouble(), (wLng as num).toDouble());
          }
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try { 
        _zoneMapController.move(_warehouseLocation, 13);
      } catch (_) {}
    });
  }

  Future<void> _detectLocation() async {
    setState(() => _detectingGeo = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) showErrorSnackBar(context, 'Доступ к геолокации запрещён');
        setState(() => _detectingGeo = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _warehouseLocation = LatLng(position.latitude, position.longitude);
        _pendingLocation = _warehouseLocation;
        _isEditingAddress = true;
      });
      _zoneMapController.move(_warehouseLocation, 15);
      if (mounted) showInfoSnackBar(context, null, 'Геолокация определена');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Ошибка: $e');
    }
    setState(() => _detectingGeo = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    
    // 1. Save delivery settings (radius, description, active)
    final settingsPayload = {
      'warehouse_id': _warehouseId,
      'is_active': _isActive,
      'delivery_radius_km': _radiusKm,
      'latitude': _warehouseLocation.latitude,
      'longitude': _warehouseLocation.longitude,
      'description': _descController.text,
      'use_akjol_couriers': true,
    };

    try {
      if (_settingsId != null) {
        await _supabase.from('delivery_settings').update(settingsPayload).eq('id', _settingsId!);
      } else {
        final result = await _supabase
            .from('delivery_settings')
            .upsert(settingsPayload, onConflict: 'warehouse_id')
            .select().single();
        _settingsId = result['id'];
      }

      // 2. Save address to warehouses if editing
      if (_isEditingAddress) {
        final newAddress = _addressController.text;
        final newLat = _pendingLocation?.latitude ?? _warehouseLocation.latitude;
        final newLng = _pendingLocation?.longitude ?? _warehouseLocation.longitude;
        await _supabase.from('warehouses').update({
          'address': newAddress,
          'latitude': newLat,
          'longitude': newLng,
        }).eq('id', _warehouseId);
        ref.read(authProvider.notifier).updateWarehouseAddress(
          _warehouseId,
          newAddress,
          newLat,
          newLng,
        );
        setState(() {
          _isEditingAddress = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Настройки сохранены'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Настройки доставки')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки доставки'),
        actions: [
          TextButton.icon(
            onPressed: (_saving || _loadingEco) ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: const Text('Сохранить'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Active toggle
          Card(
            child: SwitchListTile(
              title: const Text('Доставка активна', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_isActive ? 'Покупатели видят ваш магазин' : 'Магазин скрыт от покупателей'),
              value: _isActive,
              activeThumbColor: Colors.green,
              onChanged: (v) => setState(() => _isActive = v),
            ),
          ),
          const SizedBox(height: 16),

          // Warning banners removed since stores can place location point anywhere

          // Map Section
          const Text('Настройка на карте', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          Text(
            'Нажмите на карту, чтобы установить маркер склада/магазина.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),

          Container(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              FlutterMap(
                mapController: _zoneMapController,
                options: MapOptions(
                  initialCenter: _warehouseLocation, initialZoom: 13,
                  onTap: (_, point) {
                    setState(() {
                      _warehouseLocation = point;
                      _pendingLocation = point;
                      _isEditingAddress = true;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.takesep.app',
                  ),
                  PolygonLayer(polygons: [
                    ..._ecosystemZones.where((z) => z['polygon_points'] != null).map((z) {
                      final rawPoints = z['polygon_points'] as List<dynamic>;
                      final points = rawPoints.map((pt) {
                        final list = pt as List;
                        return LatLng((list[0] as num).toDouble(), (list[1] as num).toDouble());
                      }).toList();
                      return Polygon(
                        points: points,
                        color: Colors.red.withValues(alpha: 0.05),
                        borderColor: Colors.red.withValues(alpha: 0.3),
                        borderStrokeWidth: 2,
                        isFilled: true,
                      );
                    }),
                  ]),
                  CircleLayer(circles: [
                    ..._ecosystemZones.where((z) => z['radius_km'] != null && z['polygon_points'] == null).map((z) => CircleMarker(
                          point: LatLng((z['center_lat'] as num).toDouble(), (z['center_lng'] as num).toDouble()),
                          color: Colors.red.withValues(alpha: 0.1),
                          borderColor: Colors.red.withValues(alpha: 0.5),
                          borderStrokeWidth: 2,
                          useRadiusInMeter: true,
                          radius: (z['radius_km'] as num).toDouble() * 1000,
                        )),
                  ]),
                  MarkerLayer(markers: [
                    Marker(point: _warehouseLocation, width: 44, height: 44,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_on, color: Colors.green, size: 44)),
                  ]),
                ],
              ),
              Positioned(left: 8, top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    'Склад: ${_warehouseLocation.latitude.toStringAsFixed(4)}, ${_warehouseLocation.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                ),
              ),
              Positioned(right: 12, bottom: 12,
                child: Column(children: [
                  FloatingActionButton.small(heroTag: 'map_in', child: const Icon(Icons.add),
                    onPressed: () => _zoneMapController.move(_zoneMapController.camera.center, _zoneMapController.camera.zoom + 1)),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(heroTag: 'map_out', child: const Icon(Icons.remove),
                    onPressed: () => _zoneMapController.move(_zoneMapController.camera.center, _zoneMapController.camera.zoom - 1)),
                ]),
              ),
            ]),
          ),
          
          // Radius settings and sliders are removed
          
          const Divider(height: 48),

          if (!_isEditingAddress)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _isEditingAddress = true),
                icon: const Icon(Icons.edit_location_alt_rounded),
                label: const Text('Изменить адрес или координаты'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

          if (_isEditingAddress)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity, height: 44,
                child: OutlinedButton.icon(
                  onPressed: _detectingGeo ? null : _detectLocation,
                  icon: _detectingGeo
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location_rounded, size: 20),
                  label: Text(_detectingGeo ? 'Определяем...' : 'Определить геолокацию'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),

          // Address
          const Text('Адрес магазина', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            readOnly: !_isEditingAddress,
            decoration: InputDecoration(
              hintText: 'Улица, номер дома',
              prefixIcon: const Icon(Icons.location_on_outlined),
              filled: !_isEditingAddress,
              fillColor: Colors.grey.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(height: 16),

          // Description
          const Text('Описание магазина', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              hintText: 'Продукты, хозтовары...', prefixIcon: Icon(Icons.description_outlined)),
            maxLines: 2,
          ),
          const SizedBox(height: 24),

          // Info
          Card(
            color: Colors.green.withValues(alpha: 0.05),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.green),
                  SizedBox(width: 6),
                  Text('Доставка AkJol', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
                ]),
                SizedBox(height: 8),
                Text('• Курьеры AkJol доставят заказы\n'
                    '• Электровелосипед / Муравей\n'
                    '• Клиент выбирает транспорт\n'
                    '• Лого и баннер → Настройки → Витрина',
                    style: TextStyle(fontSize: 13, height: 1.5)),
              ]),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
