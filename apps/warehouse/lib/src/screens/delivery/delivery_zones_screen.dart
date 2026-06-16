import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

import '../../providers/auth_providers.dart';
import '../../utils/snackbar_helper.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../utils/snackbar_helper.dart';

/// Города Кыргызстана для быстрого выбора
const _kgCities = [
  {'id': 'bishkek',     'name': 'Бишкек',        'lat': 42.8746, 'lng': 74.5698},
  {'id': 'osh',         'name': 'Ош',            'lat': 40.5333, 'lng': 72.8000},
  {'id': 'jalal_abad',  'name': 'Джалал-Абад',   'lat': 40.9333, 'lng': 73.0000},
  {'id': 'karakol',     'name': 'Каракол',       'lat': 42.4903, 'lng': 78.3936},
  {'id': 'tokmok',      'name': 'Токмок',        'lat': 42.7667, 'lng': 75.3000},
  {'id': 'balykchy',    'name': 'Балыкчы',       'lat': 42.4600, 'lng': 76.1900},
  {'id': 'kara_balta',  'name': 'Кара-Балта',    'lat': 42.8167, 'lng': 73.8500},
  {'id': 'uzgen',       'name': 'Узген',         'lat': 40.7700, 'lng': 73.3000},
  {'id': 'naryn',       'name': 'Нарын',         'lat': 41.4300, 'lng': 76.0000},
  {'id': 'talas',       'name': 'Талас',         'lat': 42.5200, 'lng': 72.2400},
  {'id': 'batken',      'name': 'Баткен',        'lat': 40.0600, 'lng': 70.8200},
  {'id': 'cholpon_ata', 'name': 'Чолпон-Ата',    'lat': 42.6531, 'lng': 77.0861},
  {'id': 'kyzyl_kiya',  'name': 'Кызыл-Кия',    'lat': 40.2600, 'lng': 72.1300},
  {'id': 'kant',        'name': 'Кант',          'lat': 42.8917, 'lng': 74.8514},
];

/// Настройка зон доставки бизнеса
class DeliveryZonesScreen extends ConsumerStatefulWidget {
  const DeliveryZonesScreen({super.key});

  @override
  ConsumerState<DeliveryZonesScreen> createState() => _DeliveryZonesScreenState();
}

class _DeliveryZonesScreenState extends ConsumerState<DeliveryZonesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _zones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  String get _warehouseId => ref.read(selectedWarehouseIdProvider) ?? '';
  String get _companyId => ref.read(currentCompanyProvider)?.id ?? '';

  Future<void> _loadZones() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('delivery_zones')
          .select()
          .eq('warehouse_id', _warehouseId)
          .order('priority', ascending: false);
      setState(() {
        _zones = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addRadiusZone() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _RadiusZoneDialog(),
    );
    if (result == null) return;

    await _supabase.from('delivery_zones').insert({
      'warehouse_id': _warehouseId,
      'company_id': _companyId,
      'zone_type': 'radius',
      'name': result['name'],
      'center_lat': result['lat'],
      'center_lng': result['lng'],
      'radius_km': result['radius'],
      'delivery_fee': result['fee'] ?? 0,
      'free_delivery_from': result['free_from'] ?? 0,
      'fee_per_km': result['per_km'] ?? 0,
      'min_order_amount': result['min_order'] ?? 0,
      'estimated_minutes': result['minutes'] ?? 60,
    });
    _loadZones();
  }

  Future<void> _addCityZone() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _CityZoneDialog(),
    );
    if (result == null) return;

    await _supabase.from('delivery_zones').insert({
      'warehouse_id': _warehouseId,
      'company_id': _companyId,
      'zone_type': 'city',
      'name': 'г. ${result['name']}',
      'geo_name': result['name'],
      'center_lat': result['lat'],
      'center_lng': result['lng'],
      'delivery_fee': result['fee'] ?? 0,
      'free_delivery_from': result['free_from'] ?? 0,
      'min_order_amount': result['min_order'] ?? 0,
      'estimated_minutes': result['minutes'] ?? 90,
    });
    _loadZones();
  }

  Future<void> _addCountryZone() async {
    final feeCtrl = TextEditingController(text: '300');
    final minCtrl = TextEditingController(text: '1000');
    final minutesCtrl = TextEditingController(text: '1440');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Вся Кыргызская Республика'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ваши товары будут доступны для заказа из любой точки КР.',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(controller: feeCtrl, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Стоимость доставки (сом)', suffixText: 'сом')),
            const SizedBox(height: 8),
            TextField(controller: minCtrl, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Мин. заказ (сом)', suffixText: 'сом')),
            const SizedBox(height: 8),
            TextField(controller: minutesCtrl, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Время доставки (мин)', suffixText: 'мин')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Добавить')),
        ],
      ),
    );

    if (confirmed == true) {
      await _supabase.from('delivery_zones').insert({
        'warehouse_id': _warehouseId,
        'company_id': _companyId,
        'zone_type': 'country',
        'name': 'Вся Кыргызская Республика 🇰🇬',
        'geo_name': 'KG',
        'delivery_fee': double.tryParse(feeCtrl.text) ?? 300,
        'min_order_amount': double.tryParse(minCtrl.text) ?? 1000,
        'estimated_minutes': int.tryParse(minutesCtrl.text) ?? 1440,
      });
      _loadZones();
    }
  }

  Future<void> _toggleZone(Map<String, dynamic> zone) async {
    await _supabase.from('delivery_zones').update({
      'is_active': !(zone['is_active'] as bool),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', zone['id']);
    _loadZones();
  }

  Future<void> _deleteZone(Map<String, dynamic> zone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить зону?'),
        content: Text('Зона "${zone['name']}" будет удалена.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _supabase.from('delivery_zones').delete().eq('id', zone['id']);
      _loadZones();
      if (mounted) showInfoSnackBar(context, null, 'Зона удалена');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.map_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Зоны доставки',
                              style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                            '${_zones.where((z) => z['is_active'] == true).length} активных зон',
                            style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Add zone buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _addButton(
                      icon: Icons.radar_rounded,
                      label: 'По радиусу',
                      color: Colors.blue,
                      onTap: _addRadiusZone,
                    ),
                    _addButton(
                      icon: Icons.location_city_rounded,
                      label: 'По городу',
                      color: Colors.green,
                      onTap: _addCityZone,
                    ),
                    _addButton(
                      icon: Icons.public_rounded,
                      label: 'Вся страна',
                      color: Colors.orange,
                      onTap: _addCountryZone,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Zones list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _zones.isEmpty
                    ? _buildEmptyState(cs)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _zones.length,
                        itemBuilder: (_, idx) => _buildZoneTile(_zones[idx], cs),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _addButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.2)),
      onPressed: onTap,
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 80, color: cs.onSurface.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text('Нет зон доставки',
              style: AppTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 8),
          Text('Добавьте зону чтобы клиенты могли\nзаказать доставку через AkJol',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  Widget _buildZoneTile(Map<String, dynamic> zone, ColorScheme cs) {
    final isActive = zone['is_active'] as bool? ?? false;
    final type = zone['zone_type'] as String? ?? 'radius';
    final name = zone['name'] as String? ?? '';
    final fee = (zone['delivery_fee'] as num?)?.toDouble() ?? 0;
    final minOrder = (zone['min_order_amount'] as num?)?.toDouble() ?? 0;
    final freeFrom = (zone['free_delivery_from'] as num?)?.toDouble() ?? 0;
    final minutes = zone['estimated_minutes'] as int? ?? 60;

    final (IconData icon, Color color) = switch (type) {
      'radius'  => (Icons.radar_rounded, Colors.blue),
      'city'    => (Icons.location_city_rounded, Colors.green),
      'region'  => (Icons.terrain_rounded, Colors.teal),
      'country' => (Icons.public_rounded, Colors.orange),
      _         => (Icons.place_rounded, Colors.grey),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? color.withValues(alpha: 0.3) : cs.outlineVariant.withValues(alpha: 0.2),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isActive ? 0.1 : 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isActive ? color : Colors.grey, size: 22),
            ),
            title: Text(name, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            subtitle: _buildZoneDetails(type, zone, fee, freeFrom, minOrder, minutes, cs),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 18, color: cs.onSurface.withValues(alpha: 0.3)),
                  onPressed: () => _deleteZone(zone),
                ),
                Switch(
                  value: isActive,
                  onChanged: (_) => _toggleZone(zone),
                  activeTrackColor: color,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneDetails(String type, Map<String, dynamic> zone,
      double fee, double freeFrom, double minOrder, int minutes, ColorScheme cs) {
    final items = <String>[];

    if (type == 'radius') {
      final radius = (zone['radius_km'] as num?)?.toDouble() ?? 0;
      items.add('📏 ${radius.toStringAsFixed(0)} км');
    }
    if (fee > 0) items.add('💰 ${fee.toStringAsFixed(0)} сом');
    if (freeFrom > 0) items.add('🆓 от ${freeFrom.toStringAsFixed(0)}');
    if (minOrder > 0) items.add('📦 мин. ${minOrder.toStringAsFixed(0)}');

    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      items.add('⏱ ${hours}ч${mins > 0 ? " ${mins}м" : ""}');
    } else {
      items.add('⏱ ${minutes}м');
    }

    return Text(
      items.join(' • '),
      style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.45), fontSize: 11),
    );
  }
}

/// Диалог добавления зоны по радиусу
class _RadiusZoneDialog extends StatefulWidget {
  @override
  State<_RadiusZoneDialog> createState() => _RadiusZoneDialogState();
}

class _RadiusZoneDialogState extends State<_RadiusZoneDialog> {
  final _nameCtrl = TextEditingController(text: 'Новая зона');
  final _radiusCtrl = TextEditingController(text: '5');
  final _feeCtrl = TextEditingController(text: '100');
  final _freeFromCtrl = TextEditingController(text: '500');
  final _minOrderCtrl = TextEditingController(text: '0');
  final _minutesCtrl = TextEditingController(text: '60');

  final MapController _mapCtrl = MapController();
  LatLng _center = const LatLng(42.8746, 74.5698);
  double _radiusKm = 5.0;

  List<Map<String, dynamic>> _ecosystemZones = [];
  bool _loadingZones = true;
  String? _errorLoadingEco;

  @override
  void initState() {
    super.initState();
    _loadEcosystemZones();
    _radiusCtrl.addListener(() {
      setState(() {
        _radiusKm = double.tryParse(_radiusCtrl.text) ?? 5.0;
      });
    });
  }

  Future<void> _loadEcosystemZones() async {
    try {
      final data = await Supabase.instance.client
          .from('ecosystem_zones')
          .select()
          .eq('is_active', true);
      setState(() {
        _ecosystemZones = List<Map<String, dynamic>>.from(data);
        _loadingZones = false;
        _errorLoadingEco = null;
        if (_ecosystemZones.isNotEmpty) {
          final first = _ecosystemZones.first;
          _center = LatLng(first['center_lat'] as double, first['center_lng'] as double);
        }
      });
      if (_ecosystemZones.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _mapCtrl.move(_center, 12.0);
          } catch (e) {
            debugPrint('Error moving map in dialog: $e');
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading ecosystem zones: $e');
      setState(() {
        _errorLoadingEco = e.toString();
        _loadingZones = false;
      });
    }
  }

  bool _isWithinEcosystem() {
    if (_errorLoadingEco != null) return false;
    if (_ecosystemZones.isEmpty) return true; // No restrictions if no zones defined
    final distanceCalc = const Distance();
    
    for (final ecoZone in _ecosystemZones) {
      final ecoCenter = LatLng(ecoZone['center_lat'] as double, ecoZone['center_lng'] as double);
      final ecoRadius = (ecoZone['radius_km'] as num).toDouble();
      
      final d = distanceCalc.as(LengthUnit.Kilometer, _center, ecoCenter);
      // Our radius must fit entirely inside the ecosystem radius
      if (d + _radiusKm <= ecoRadius) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _isWithinEcosystem();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 800,
        height: 600,
        child: Row(
          children: [
            // Map side
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapCtrl,
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: 12.0,
                        onTap: (_, point) {
                          setState(() {
                            _center = point;
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                        ),
                        CircleLayer(
                          circles: [
                            // Ecosystem Zones
                            ..._ecosystemZones.map((z) => CircleMarker(
                                  point: LatLng(z['center_lat'] as double, z['center_lng'] as double),
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderColor: Colors.red.withValues(alpha: 0.5),
                                  borderStrokeWidth: 2,
                                  useRadiusInMeter: true,
                                  radius: (z['radius_km'] as num).toDouble() * 1000,
                                )),
                            // Business Zone
                            CircleMarker(
                              point: _center,
                              color: isValid
                                  ? Colors.blue.withValues(alpha: 0.2)
                                  : Colors.orange.withValues(alpha: 0.4),
                              borderColor: isValid ? Colors.blue : Colors.orange,
                              borderStrokeWidth: 2,
                              useRadiusInMeter: true,
                              radius: _radiusKm * 1000,
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Center marker icon
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: Icon(Icons.location_on, color: Colors.blue, size: 36),
                      ),
                    ),
                    // Error message overlay
                    if (!isValid)
                      Positioned(
                        bottom: 16, left: 16, right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                            border: Border.all(color: _errorLoadingEco != null ? Colors.red : Colors.orange),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _errorLoadingEco != null ? Icons.error_outline : Icons.warning_amber_rounded,
                                color: _errorLoadingEco != null ? Colors.red : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorLoadingEco != null
                                      ? 'Ошибка загрузки ограничений экосистемы: $_errorLoadingEco'
                                      : 'Ваша зона выходит за разрешенные пределы экосистемы. '
                                          'Пожалуйста, уменьшите радиус или переместите центр.',
                                  style: TextStyle(
                                    color: _errorLoadingEco != null ? Colors.red : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Form side
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.radar_rounded, color: Colors.blue, size: 24),
                        SizedBox(width: 8),
                        Text('Настройка зоны', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Нажмите на карту чтобы выбрать центр.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 16),
                            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Название зоны')),
                            const SizedBox(height: 16),
                            TextField(controller: _radiusCtrl, keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Радиус (км)', suffixText: 'км')),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: TextField(controller: _feeCtrl, keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Стоимость', suffixText: 'сом'))),
                                const SizedBox(width: 12),
                                Expanded(child: TextField(controller: _freeFromCtrl, keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Бесплатно от', suffixText: 'сом'))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: TextField(controller: _minOrderCtrl, keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Мин. заказ', suffixText: 'сом'))),
                                const SizedBox(width: 12),
                                Expanded(child: TextField(controller: _minutesCtrl, keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Время', suffixText: 'мин'))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: isValid && !_loadingZones ? () {
                            Navigator.pop(context, {
                              'name': _nameCtrl.text,
                              'lat': _center.latitude,
                              'lng': _center.longitude,
                              'radius': _radiusKm,
                              'fee': double.tryParse(_feeCtrl.text) ?? 0,
                              'free_from': double.tryParse(_freeFromCtrl.text) ?? 0,
                              'min_order': double.tryParse(_minOrderCtrl.text) ?? 0,
                              'minutes': int.tryParse(_minutesCtrl.text) ?? 60,
                            });
                          } : null,
                          child: const Text('Сохранить'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Диалог добавления зоны по городу
class _CityZoneDialog extends StatefulWidget {
  @override
  State<_CityZoneDialog> createState() => _CityZoneDialogState();
}

class _CityZoneDialogState extends State<_CityZoneDialog> {
  final _feeCtrl = TextEditingController(text: '150');
  final _freeFromCtrl = TextEditingController(text: '1000');
  final _minOrderCtrl = TextEditingController(text: '200');
  final _minutesCtrl = TextEditingController(text: '90');
  final Set<String> _selectedCities = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.location_city_rounded, color: Colors.green, size: 22),
          SizedBox(width: 8),
          Text('Выберите города'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Города доставки', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _kgCities.map((city) {
                  final cityName = city['name'] as String;
                  final isSelected = _selectedCities.contains(cityName);
                  return FilterChip(
                    label: Text(cityName, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    selectedColor: Colors.green.withValues(alpha: 0.15),
                    checkmarkColor: Colors.green,
                    onSelected: (v) {
                      setState(() {
                        if (v) { _selectedCities.add(cityName); }
                        else { _selectedCities.remove(cityName); }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(controller: _feeCtrl, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Стоимость', suffixText: 'сом'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _freeFromCtrl, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Бесплатно от', suffixText: 'сом'))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: _minOrderCtrl, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Мин. заказ', suffixText: 'сом'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _minutesCtrl, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Время', suffixText: 'мин'))),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          onPressed: _selectedCities.isEmpty ? null : () {
            // Return first selected; caller can iterate
            final firstCity = _kgCities.firstWhere((c) => c['name'] == _selectedCities.first);
            Navigator.pop(context, {
              'name': _selectedCities.first,
              'lat': firstCity['lat'],
              'lng': firstCity['lng'],
              'cities': _selectedCities.toList(),
              'fee': double.tryParse(_feeCtrl.text) ?? 0,
              'free_from': double.tryParse(_freeFromCtrl.text) ?? 0,
              'min_order': double.tryParse(_minOrderCtrl.text) ?? 0,
              'minutes': int.tryParse(_minutesCtrl.text) ?? 90,
            });
          },
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}
