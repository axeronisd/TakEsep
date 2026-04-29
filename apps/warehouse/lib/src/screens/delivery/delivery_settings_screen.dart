import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../utils/snackbar_helper.dart';

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

  final MapController _mapController = MapController();
  LatLng _warehouseLocation = const LatLng(42.8746, 74.5698);
  double _radiusKm = 3.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _descController.dispose();
    super.dispose();
  }

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
          _addressController.text = data['address'] ?? '';
          _descController.text = data['description'] ?? '';
          _radiusKm = (data['delivery_radius_km'] ?? 3.0).toDouble();
          final lat = data['latitude'];
          final lng = data['longitude'];
          if (lat != null && lng != null) {
            _warehouseLocation = LatLng((lat as num).toDouble(), (lng as num).toDouble());
          }
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try { _mapController.move(_warehouseLocation, 13); } catch (_) {}
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
      setState(() => _warehouseLocation = LatLng(position.latitude, position.longitude));
      _mapController.move(_warehouseLocation, 15);
      if (mounted) showInfoSnackBar(context, null, 'Геолокация определена');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Ошибка: $e');
    }
    setState(() => _detectingGeo = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final payload = {
      'warehouse_id': _warehouseId,
      'is_active': _isActive,
      'address': _addressController.text,
      'delivery_radius_km': _radiusKm,
      'latitude': _warehouseLocation.latitude,
      'longitude': _warehouseLocation.longitude,
      'description': _descController.text,
      'use_akjol_couriers': true,
    };

    try {
      if (_settingsId != null) {
        await _supabase.from('delivery_settings').update(payload).eq('id', _settingsId!);
      } else {
        final result = await _supabase
            .from('delivery_settings')
            .upsert(payload, onConflict: 'warehouse_id')
            .select().single();
        _settingsId = result['id'];
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
            onPressed: _saving ? null : _save,
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

          // Map section
          const Text('Расположение магазина', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Нажмите на карту или определите по GPS', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 12),

          SizedBox(
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
          const SizedBox(height: 12),

          Container(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _warehouseLocation, initialZoom: 13,
                  onTap: (_, point) => setState(() => _warehouseLocation = point),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.takesep.app',
                  ),
                  CircleLayer(circles: [
                    CircleMarker(
                      point: _warehouseLocation,
                      color: Colors.green.withValues(alpha: 0.15),
                      borderColor: Colors.green, borderStrokeWidth: 2,
                      useRadiusInMeter: true, radius: _radiusKm * 1000,
                    ),
                  ]),
                  MarkerLayer(markers: [
                    Marker(point: _warehouseLocation, width: 44, height: 44,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 44)),
                  ]),
                ],
              ),
              Positioned(left: 8, top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    '${_warehouseLocation.latitude.toStringAsFixed(4)}, ${_warehouseLocation.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                ),
              ),
              Positioned(right: 12, bottom: 12,
                child: Column(children: [
                  FloatingActionButton.small(heroTag: 'zin', child: const Icon(Icons.add),
                    onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(heroTag: 'zout', child: const Icon(Icons.remove),
                    onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // Radius
          Row(children: [
            const Text('Радиус: ', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('${_radiusKm.toStringAsFixed(1)} км',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 16)),
            Expanded(
              child: Slider(
                value: _radiusKm, min: 0.5, max: 15.0, divisions: 29,
                activeColor: Colors.green,
                onChanged: (v) => setState(() => _radiusKm = v),
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // Address
          const Text('Адрес магазина', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              hintText: 'Улица, номер дома', prefixIcon: Icon(Icons.location_on_outlined)),
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
