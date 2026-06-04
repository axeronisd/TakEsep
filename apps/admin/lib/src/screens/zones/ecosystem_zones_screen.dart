import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class EcosystemZonesScreen extends ConsumerStatefulWidget {
  const EcosystemZonesScreen({super.key});

  @override
  ConsumerState<EcosystemZonesScreen> createState() => _EcosystemZonesScreenState();
}

class _EcosystemZonesScreenState extends ConsumerState<EcosystemZonesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _zones = [];
  bool _loading = true;

  final MapController _mapCtrl = MapController();
  LatLng _center = const LatLng(42.8746, 74.5698); // Bishkek
  double _zoom = 12.0;

  bool _isAdding = false;
  LatLng? _newZoneCenter;
  double _newZoneRadiusKm = 10.0;
  final _nameCtrl = TextEditingController(text: 'Новая зона');

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase.from('ecosystem_zones').select().order('created_at');
      setState(() {
        _zones = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
      if (_zones.isNotEmpty) {
        final first = _zones.first;
        _center = LatLng(first['center_lat'] as double, first['center_lng'] as double);
        _mapCtrl.move(_center, _zoom);
      }
    } catch (e) {
      debugPrint('Load zones error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _saveNewZone() async {
    if (_newZoneCenter == null) return;
    setState(() => _loading = true);
    try {
      await _supabase.from('ecosystem_zones').insert({
        'name': _nameCtrl.text,
        'center_lat': _newZoneCenter!.latitude,
        'center_lng': _newZoneCenter!.longitude,
        'radius_km': _newZoneRadiusKm,
        'is_active': true,
      });
      setState(() {
        _isAdding = false;
        _newZoneCenter = null;
      });
      _loadZones();
    } catch (e) {
      debugPrint('Save zone error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteZone(String id) async {
    setState(() => _loading = true);
    try {
      await _supabase.from('ecosystem_zones').delete().eq('id', id);
      _loadZones();
    } catch (e) {
      debugPrint('Delete zone error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleZone(String id, bool active) async {
    setState(() => _loading = true);
    try {
      await _supabase.from('ecosystem_zones').update({'is_active': active}).eq('id', id);
      _loadZones();
    } catch (e) {
      debugPrint('Toggle zone error: $e');
      setState(() => _loading = false);
    }
  }

  void _startAddingMode() {
    setState(() {
      _isAdding = true;
      _newZoneCenter = _mapCtrl.camera.center;
      _nameCtrl.text = 'Новая зона';
      _newZoneRadiusKm = 10.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Row(
        children: [
          // Sidebar with zones list
          Container(
            width: 320,
            color: AppColors.darkSurface,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.darkBorder.withValues(alpha: 0.5))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Зоны Экосистемы',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ограничивают область доставки для складов',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isAdding ? null : _startAddingMode,
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить зону'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading && _zones.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: _zones.length,
                          itemBuilder: (context, index) {
                            final zone = _zones[index];
                            final id = zone['id'] as String;
                            final name = zone['name'] as String;
                            final radius = zone['radius_km'] as num;
                            final isActive = zone['is_active'] as bool? ?? true;

                            return ListTile(
                              title: Text(name, style: const TextStyle(color: Colors.white)),
                              subtitle: Text('Радиус: ${radius} км', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: isActive,
                                    onChanged: (v) => _toggleZone(id, v),
                                    activeColor: AppColors.primary,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                    onPressed: () => _deleteZone(id),
                                  ),
                                ],
                              ),
                              onTap: () {
                                _mapCtrl.move(
                                  LatLng(zone['center_lat'] as double, zone['center_lng'] as double),
                                  12.0,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          
          // Map View
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: _zoom,
                    onPositionChanged: (pos, hasGesture) {
                      if (_isAdding && hasGesture) {
                        setState(() {
                          _newZoneCenter = pos.center;
                        });
                      }
                    },
                    onTap: (tapPos, p) {
                      if (_isAdding) {
                        setState(() {
                          _newZoneCenter = p;
                        });
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                    ),
                    CircleLayer(
                      circles: [
                        // Existing zones
                        ..._zones.map((z) {
                          final isActive = z['is_active'] as bool? ?? true;
                          return CircleMarker(
                            point: LatLng(z['center_lat'] as double, z['center_lng'] as double),
                            color: isActive ? Colors.blue.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                            borderColor: isActive ? Colors.blue : Colors.grey,
                            borderStrokeWidth: 2,
                            useRadiusInMeter: true,
                            radius: (z['radius_km'] as num).toDouble() * 1000,
                          );
                        }),
                        // New zone being added
                        if (_isAdding && _newZoneCenter != null)
                          CircleMarker(
                            point: _newZoneCenter!,
                            color: Colors.green.withValues(alpha: 0.3),
                            borderColor: Colors.green,
                            borderStrokeWidth: 2,
                            useRadiusInMeter: true,
                            radius: _newZoneRadiusKm * 1000,
                          ),
                      ],
                    ),
                  ],
                ),

                // Overlay for adding mode
                if (_isAdding)
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      width: 300,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Режим добавления зоны', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _nameCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Название зоны',
                              labelStyle: TextStyle(color: Colors.white54),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text('Радиус (км): ', style: TextStyle(color: Colors.white54)),
                              Expanded(
                                child: Slider(
                                  value: _newZoneRadiusKm,
                                  min: 1.0,
                                  max: 50.0,
                                  activeColor: Colors.green,
                                  onChanged: (v) {
                                    setState(() {
                                      _newZoneRadiusKm = v;
                                    });
                                  },
                                ),
                              ),
                              Text('${_newZoneRadiusKm.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isAdding = false;
                                    _newZoneCenter = null;
                                  });
                                },
                                child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                onPressed: _loading ? null : _saveNewZone,
                                child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                // Center marker
                if (_isAdding)
                  const Center(
                    child: Icon(Icons.location_on, color: Colors.green, size: 40),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
