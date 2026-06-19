import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class EcosystemZonesScreen extends ConsumerStatefulWidget {
  const EcosystemZonesScreen({super.key});

  @override
  ConsumerState<EcosystemZonesScreen> createState() =>
      _EcosystemZonesScreenState();
}

class _EcosystemZonesScreenState extends ConsumerState<EcosystemZonesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _zones = [];
  bool _loading = true;

  final MapController _mapCtrl = MapController();
  LatLng _center = const LatLng(42.8746, 74.5698); // Bishkek
  double _zoom = 12.0;

  bool _isAdding = false;
  String? _editingZoneId;
  final List<LatLng> _newPolygonPoints = [];
  final _nameCtrl = TextEditingController(text: 'Новая зона');
  bool _showMapOnMobile = true;

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    setState(() => _loading = true);
    try {
      final data =
          await _supabase.from('ecosystem_zones').select().order('created_at');
      setState(() {
        _zones = List<Map<String, dynamic>>.from(data);
        _loading = false;
        if (_zones.isNotEmpty) {
          final first = _zones.first;
          _center = LatLng(
              first['center_lat'] as double, first['center_lng'] as double);
        }
      });
      if (_zones.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _mapCtrl.move(_center, _zoom);
          } catch (e) {
            debugPrint('Load zones map move error: $e');
          }
        });
      }
    } catch (e) {
      debugPrint('Load zones error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _saveZone() async {
    if (_newPolygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Для сохранения полигона необходимо как минимум 3 точки')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final firstPoint = _newPolygonPoints.first;
      final payload = {
        'name': _nameCtrl.text,
        'center_lat': firstPoint.latitude,
        'center_lng': firstPoint.longitude,
        'polygon_points': _newPolygonPoints.map((p) => [p.latitude, p.longitude]).toList(),
        'is_active': true,
      };

      if (_editingZoneId != null) {
        await _supabase.from('ecosystem_zones').update(payload).eq('id', _editingZoneId!);
      } else {
        await _supabase.from('ecosystem_zones').insert(payload);
      }

      setState(() {
        _isAdding = false;
        _editingZoneId = null;
        _newPolygonPoints.clear();
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
      await _supabase
          .from('ecosystem_zones')
          .update({'is_active': active}).eq('id', id);
      _loadZones();
    } catch (e) {
      debugPrint('Toggle zone error: $e');
      setState(() => _loading = false);
    }
  }

  void _startAddingMode() {
    setState(() {
      _isAdding = true;
      _editingZoneId = null;
      _newPolygonPoints.clear();
      _nameCtrl.text = 'Новая зона';
    });
  }

  void _startEditingMode(Map<String, dynamic> zone) {
    setState(() {
      _editingZoneId = zone['id'] as String;
      _isAdding = false;
      _newPolygonPoints.clear();
      _nameCtrl.text = zone['name'] as String;

      final polygonPoints = zone['polygon_points'] as List<dynamic>?;
      if (polygonPoints != null) {
        for (final pt in polygonPoints) {
          final list = pt as List<dynamic>;
          _newPolygonPoints.add(LatLng((list[0] as num).toDouble(), (list[1] as num).toDouble()));
        }
      }

      _center = LatLng(zone['center_lat'] as double, zone['center_lng'] as double);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapCtrl.move(_center, _zoom);
      } catch (e) {
        debugPrint('Move map error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 760;

    Widget listPanel = Container(
      width: isMobile ? double.infinity : 320,
      color: AppColors.darkSurface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: AppColors.darkBorder.withValues(alpha: 0.5))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Зоны Экосистемы',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ограничивают область доставки для складов',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isAdding || _editingZoneId != null
                      ? null
                      : () {
                          if (isMobile) {
                            setState(() {
                              _showMapOnMobile = true;
                              _startAddingMode();
                            });
                          } else {
                            _startAddingMode();
                          }
                        },
                  icon: const Icon(Icons.add_rounded),
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
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    itemCount: _zones.length,
                    itemBuilder: (context, index) {
                      final zone = _zones[index];
                      final id = zone['id'] as String;
                      final name = zone['name'] as String;
                      final radius = zone['radius_km'] as num?;
                      final polygonPoints = zone['polygon_points'] as List<dynamic>?;
                      final isActive = zone['is_active'] as bool? ?? true;

                      return ListTile(
                        title: Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            polygonPoints != null
                                ? 'Полигон: ${polygonPoints.length} точек'
                                : 'Радиус: ${radius ?? 0} км',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5))),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_rounded,
                                  color: AppColors.info),
                              onPressed: () {
                                if (isMobile) {
                                  setState(() {
                                    _showMapOnMobile = true;
                                  });
                                }
                                _startEditingMode(zone);
                              },
                            ),
                            Switch(
                              value: isActive,
                              onChanged: (v) => _toggleZone(id, v),
                              activeThumbColor: AppColors.primary,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_rounded,
                                  color: AppColors.errorLight),
                              onPressed: () => _deleteZone(id),
                            ),
                          ],
                        ),
                        onTap: () {
                          if (isMobile) {
                            setState(() {
                              _showMapOnMobile = true;
                            });
                          }
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _mapCtrl.move(
                              LatLng(zone['center_lat'] as double,
                                  zone['center_lng'] as double),
                              12.0,
                            );
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    Widget mapPanel = Stack(
      children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: _zoom,
            onTap: (tapPos, p) {
              if (_isAdding || _editingZoneId != null) {
                setState(() {
                  _newPolygonPoints.add(p);
                });
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
            ),
            PolygonLayer(
              polygons: [
                // Render existing polygon zones (excluding the one being edited)
                ..._zones.where((z) => z['polygon_points'] != null && z['id'] != _editingZoneId).map((z) {
                  final isActive = z['is_active'] as bool? ?? true;
                  final rawPoints = z['polygon_points'] as List<dynamic>;
                  final points = rawPoints.map((pt) {
                    final list = pt as List<dynamic>;
                    return LatLng((list[0] as num).toDouble(), (list[1] as num).toDouble());
                  }).toList();
                  return Polygon(
                    points: points,
                    color: isActive
                        ? AppColors.info.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.2),
                    borderColor: isActive ? AppColors.info : Colors.grey,
                    borderStrokeWidth: 2,
                    isFilled: true,
                  );
                }),
                // Render new polygon zone being added or edited
                if ((_isAdding || _editingZoneId != null) && _newPolygonPoints.length >= 2)
                  Polygon(
                    points: _newPolygonPoints,
                    color: (_editingZoneId != null ? AppColors.info : AppColors.success).withValues(alpha: 0.3),
                    borderColor: _editingZoneId != null ? AppColors.info : AppColors.success,
                    borderStrokeWidth: 2,
                    isFilled: true,
                  ),
              ],
            ),
            CircleLayer(
              circles: [
                // Render legacy radius zones (excluding the one being edited)
                ..._zones.where((z) => z['polygon_points'] == null && z['id'] != _editingZoneId).map((z) {
                  final isActive = z['is_active'] as bool? ?? true;
                  final radius = z['radius_km'] as num?;
                  return CircleMarker(
                    point: LatLng(
                        z['center_lat'] as double, z['center_lng'] as double),
                    color: isActive
                        ? AppColors.info.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.2),
                    borderColor: isActive ? AppColors.info : Colors.grey,
                    borderStrokeWidth: 2,
                    useRadiusInMeter: true,
                    radius: (radius?.toDouble() ?? 0) * 1000,
                  );
                }),
              ],
            ),
            MarkerLayer(
              markers: [
                if (_isAdding || _editingZoneId != null)
                  ..._newPolygonPoints.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final pt = entry.value;
                    return Marker(
                      point: pt,
                      width: 28,
                      height: 28,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _newPolygonPoints.removeAt(idx);
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _editingZoneId != null ? AppColors.info : AppColors.success,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ],
        ),

        // Overlay for adding/editing mode
        if (_isAdding || _editingZoneId != null)
          Positioned(
            top: 20,
            right: 20,
            left: isMobile ? 20 : null,
            child: Container(
              width: isMobile ? double.infinity : 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: (_editingZoneId != null ? AppColors.info : AppColors.success).withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_editingZoneId != null ? 'Режим редактирования зоны' : 'Режим добавления зоны (Полигон)',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Нажимайте на карту, чтобы поставить вершины полигона.\nНажмите на вершину с номером, чтобы удалить её.',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Вершин: ${_newPolygonPoints.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      Row(
                        children: [
                          if (_newPolygonPoints.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.undo_rounded, color: Colors.white70, size: 20),
                              tooltip: 'Отменить точку',
                              onPressed: () {
                                setState(() {
                                  _newPolygonPoints.removeLast();
                                });
                              },
                            ),
                          if (_newPolygonPoints.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.errorLight, size: 20),
                              tooltip: 'Сбросить все',
                              onPressed: () {
                                setState(() {
                                  _newPolygonPoints.clear();
                                });
                              },
                            ),
                        ],
                      ),
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
                            _editingZoneId = null;
                            _newPolygonPoints.clear();
                          });
                        },
                        child: const Text('Отмена',
                            style: TextStyle(color: Colors.white54)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: _editingZoneId != null ? AppColors.info : AppColors.success),
                        onPressed: _loading ? null : _saveZone,
                        child: const Text('Сохранить',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: () =>
                  setState(() => _showMapOnMobile = !_showMapOnMobile),
              icon: Icon(
                  _showMapOnMobile ? Icons.list_rounded : Icons.map_rounded),
              label: Text(_showMapOnMobile ? 'Список' : 'Карта'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
      body: isMobile
          ? (_showMapOnMobile ? mapPanel : listPanel)
          : Row(
              children: [
                listPanel,
                Expanded(child: mapPanel),
              ],
            ),
    );
  }
}
