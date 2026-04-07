import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../providers/auth_providers.dart';
import '../../utils/snackbar_helper.dart';

/// Города Кыргызстана
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

class DeliverySettingsScreen extends ConsumerStatefulWidget {
  final String warehouseId;
  const DeliverySettingsScreen({super.key, required this.warehouseId});

  @override
  ConsumerState<DeliverySettingsScreen> createState() => _DeliverySettingsScreenState();
}

class _DeliverySettingsScreenState extends ConsumerState<DeliverySettingsScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabCtrl;

  // Settings
  final _addressController = TextEditingController();
  final _minOrderController = TextEditingController(text: '0');
  final _descController = TextEditingController();
  bool _isActive = false;
  bool _loading = true;
  bool _saving = false;
  String? _settingsId;

  // Map
  final MapController _mapController = MapController();
  LatLng _warehouseLocation = const LatLng(42.8746, 74.5698);
  double _radiusKm = 3.0;

  // Transports
  Set<String> _selectedTransports = {'bicycle'};
  List<Map<String, dynamic>> _allTransports = [];

  // Cascading routing
  bool _useAkjolCouriers = true;
  int _priorityMinutes = 2;

  // Zones
  List<Map<String, dynamic>> _zones = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadSettings();
    _loadTransports();
    _loadZones();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _addressController.dispose();
    _minOrderController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String get _warehouseId => widget.warehouseId;

  // ═══════════════════════════════════════
  // Data Loading
  // ═══════════════════════════════════════

  Future<void> _loadTransports() async {
    try {
      final data = await _supabase.from('transport_types').select('*');
      setState(() => _allTransports = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

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
          _minOrderController.text = '${data['min_order_amount'] ?? 0}';
          _descController.text = data['description'] ?? '';
          _radiusKm = (data['delivery_radius_km'] ?? 3.0).toDouble();

          final lat = data['latitude'];
          final lng = data['longitude'];
          if (lat != null && lng != null) {
            _warehouseLocation = LatLng((lat as num).toDouble(), (lng as num).toDouble());
          }

          _selectedTransports = Set<String>.from(data['available_transports'] ?? ['bicycle']);
          _useAkjolCouriers = data['use_akjol_couriers'] ?? true;
          _priorityMinutes = (data['store_courier_priority_minutes'] as num?)?.toInt() ?? 2;
        });
      }
    } catch (_) {}
    setState(() => _loading = false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.move(_warehouseLocation, 13);
      } catch (_) {}
    });
  }

  Future<void> _loadZones() async {
    try {
      final data = await _supabase
          .from('delivery_zones')
          .select()
          .eq('warehouse_id', _warehouseId)
          .order('priority', ascending: false);
      setState(() => _zones = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  // ═══════════════════════════════════════
  // Save Settings
  // ═══════════════════════════════════════

  Future<void> _save() async {
    setState(() => _saving = true);

    final payload = {
      'warehouse_id': _warehouseId,
      'is_active': _isActive,
      'address': _addressController.text,
      'delivery_radius_km': _radiusKm,
      'latitude': _warehouseLocation.latitude,
      'longitude': _warehouseLocation.longitude,
      'min_order_amount': double.tryParse(_minOrderController.text) ?? 0,
      'description': _descController.text,
      'available_transports': _selectedTransports.toList(),
      'use_akjol_couriers': _useAkjolCouriers,
      'store_courier_priority_minutes': _priorityMinutes,
    };

    try {
      if (_settingsId != null) {
        await _supabase
            .from('delivery_settings')
            .update(payload)
            .eq('id', _settingsId!);
      } else {
        final result = await _supabase
            .from('delivery_settings')
            .upsert(payload, onConflict: 'warehouse_id')
            .select()
            .single();
        _settingsId = result['id'];
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Настройки сохранены'), backgroundColor: Colors.green),
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

  // ═══════════════════════════════════════
  // Build
  // ═══════════════════════════════════════

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
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.tune, size: 18),
                const SizedBox(width: 6),
                const Text('Основное и Карта'),
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.map_rounded, size: 18),
                const SizedBox(width: 6),
                Text('Зоны (${_zones.length})'),
              ]),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildSettingsTab(),
          _buildZonesTab(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // TAB 1: Настройки + Карта
  // ═══════════════════════════════════════

  Widget _buildSettingsTab() {
    return ListView(
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
        const SizedBox(height: 8),

        // ── Cascading Routing Settings ──
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Курьеры AkJol (фрилансеры)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'Разрешить фрилансерам брать заказы, если ваши курьеры заняты'),
                value: _useAkjolCouriers,
                activeThumbColor: Colors.green,
                onChanged: (v) => setState(() => _useAkjolCouriers = v),
                secondary: Icon(
                  _useAkjolCouriers ? Icons.group : Icons.group_off,
                  color: _useAkjolCouriers ? Colors.green : Colors.grey,
                ),
              ),
              if (_useAkjolCouriers)
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.blue),
                  title: const Text('Приоритет своих курьеров'),
                  subtitle: Text(
                    '$_priorityMinutes мин ожидания перед передачей фрилансерам'),
                  trailing: SizedBox(
                    width: 80,
                    child: DropdownButton<int>(
                      value: _priorityMinutes.clamp(1, 10),
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: List.generate(
                        10,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('${i + 1} мин'),
                        ),
                      ),
                      onChanged: (v) =>
                          setState(() => _priorityMinutes = v ?? 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Map
        const Text('📍 Расположение склада (карта 2ГИС)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Кликните на карту, чтобы установить точку вашего склада',
            style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const SizedBox(height: 12),

        Container(
          height: 350,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _warehouseLocation,
                initialZoom: 13,
                onTap: (tapPosition, point) => setState(() => _warehouseLocation = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile{s}.maps.2gis.com/tiles?x={x}&y={y}&z={z}&v=1',
                  subdomains: const ['0', '1', '2', '3'],
                  userAgentPackageName: 'com.takesep.warehouse',
                ),
                CircleLayer(circles: [
                  CircleMarker(
                    point: _warehouseLocation,
                    color: Colors.green.withValues(alpha: 0.2),
                    borderColor: Colors.green,
                    borderStrokeWidth: 2,
                    useRadiusInMeter: true,
                    radius: _radiusKm * 1000,
                  ),
                ]),
                MarkerLayer(markers: [
                  Marker(
                    point: _warehouseLocation,
                    width: 44, height: 44,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 44),
                  ),
                ]),
              ],
            ),
            Positioned(
              right: 12, bottom: 12,
              child: Column(children: [
                FloatingActionButton.small(
                  heroTag: 'zin',
                  child: const Icon(Icons.add),
                  onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zout',
                  child: const Icon(Icons.remove),
                  onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // Slider
        Row(children: [
          const Text('Радиус: ', style: TextStyle(fontWeight: FontWeight.w600)),
          Text('${_radiusKm.toStringAsFixed(1)} км',
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
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
            hintText: 'Улица, номер дома (для курьеров)',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 16),

        // Description
        const Text('Описание магазина', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _descController,
          decoration: const InputDecoration(
            hintText: 'Продукты, хозтовары, бытовая химия...',
            prefixIcon: Icon(Icons.description_outlined),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),

        // Min order
        const Text('Минимальный заказ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _minOrderController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'сом', prefixIcon: Icon(Icons.payments_outlined)),
        ),
        const SizedBox(height: 24),

        // Transports
        const Text('Доступные транспорты', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Выберите какие курьеры могут возить ваши товары',
            style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const SizedBox(height: 12),
        ..._allTransports.map((t) {
          final tId = t['id'] as String;
          final isSelected = _selectedTransports.contains(tId);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isSelected ? Colors.green.withValues(alpha: 0.05) : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isSelected ? Colors.green : Colors.grey[300]!, width: isSelected ? 2 : 1),
            ),
            child: CheckboxListTile(
              value: isSelected,
              activeColor: Colors.green,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedTransports.add(tId);
                  } else if (_selectedTransports.length > 1) {
                    _selectedTransports.remove(tId);
                  }
                });
              },
              title: Row(children: [
                Icon(_transportIcon(tId), size: 24),
                const SizedBox(width: 8),
                Text(t['name'] ?? tId, style: const TextStyle(fontWeight: FontWeight.w500)),
              ]),
              subtitle: Text(
                'до ${(t['max_weight_kg'] as num).toInt()} кг • день ${(t['day_price'] as num).toInt()} сом • ночь ${(t['night_price'] as num).toInt()} сом',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
          );
        }),
        const SizedBox(height: 24),

        // Tariff info
        Card(
          color: Colors.blue.withValues(alpha: 0.05),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.info_outline, size: 18, color: Colors.blue),
                SizedBox(width: 6),
                Text('Тарифы AkJol', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue)),
              ]),
              SizedBox(height: 8),
              Text('AkJol берет комиссию только с доставки.\n'
                  'Всю сумму за ваши товары вы забираете 100%.\n'
                  'Ночной тариф для курьеров действует с 21:00.',
                  style: TextStyle(fontSize: 13)),
            ]),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // TAB 2: Зоны доставки
  // ═══════════════════════════════════════

  Widget _buildZonesTab() {
    return Column(children: [
      // Header with add buttons
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          _addButton(icon: Icons.radar_rounded, label: 'По радиусу', color: Colors.blue, onTap: _addRadiusZone),
          _addButton(icon: Icons.location_city_rounded, label: 'По городу', color: Colors.green, onTap: _addCityZone),
          _addButton(icon: Icons.public_rounded, label: 'Вся страна', color: Colors.orange, onTap: _addCountryZone),
        ]),
      ),

      Expanded(
        child: _zones.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.map_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('Нет зон доставки', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                const SizedBox(height: 8),
                Text('Добавьте зону для расширения области доставки', style: TextStyle(color: Colors.grey[400])),
              ]))
            : RefreshIndicator(
                onRefresh: _loadZones,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _zones.length,
                  itemBuilder: (_, idx) => _buildZoneTile(_zones[idx]),
                ),
              ),
      ),
    ]);
  }

  Widget _addButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.2)),
      onPressed: onTap,
    );
  }

  Widget _buildZoneTile(Map<String, dynamic> zone) {
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
    items.add(hours > 0 ? '⏱ ${hours}ч${mins > 0 ? " ${mins}м" : ""}' : '⏱ ${minutes}м');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? color.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2), width: isActive ? 1.5 : 1),
      ),
      child: ListTile(
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isActive ? 0.1 : 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: isActive ? color : Colors.grey, size: 22),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(items.join(' • '), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey[400]),
            onPressed: () => _deleteZone(zone),
          ),
          Switch(
            value: isActive,
            onChanged: (_) => _toggleZone(zone),
            activeTrackColor: color,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════
  // Zone Actions
  // ═══════════════════════════════════════

  String get _companyId => ref.read(currentCompanyProvider)?.id ?? '';

  Future<void> _addRadiusZone() async {
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _RadiusZoneDialog());
    if (result == null) return;
    await _supabase.from('delivery_zones').insert({
      'warehouse_id': _warehouseId, 'company_id': _companyId, 'zone_type': 'radius',
      'name': result['name'], 'center_lat': result['lat'], 'center_lng': result['lng'],
      'radius_km': result['radius'], 'delivery_fee': result['fee'] ?? 0,
      'free_delivery_from': result['free_from'] ?? 0, 'fee_per_km': result['per_km'] ?? 0,
      'min_order_amount': result['min_order'] ?? 0, 'estimated_minutes': result['minutes'] ?? 60,
    });
    _loadZones();
  }

  Future<void> _addCityZone() async {
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _CityZoneDialog());
    if (result == null) return;
    await _supabase.from('delivery_zones').insert({
      'warehouse_id': _warehouseId, 'company_id': _companyId, 'zone_type': 'city',
      'name': 'г. ${result['name']}', 'geo_name': result['name'],
      'center_lat': result['lat'], 'center_lng': result['lng'],
      'delivery_fee': result['fee'] ?? 0, 'free_delivery_from': result['free_from'] ?? 0,
      'min_order_amount': result['min_order'] ?? 0, 'estimated_minutes': result['minutes'] ?? 90,
    });
    _loadZones();
  }

  Future<void> _addCountryZone() async {
    final feeCtrl = TextEditingController(text: '300');
    final minCtrl = TextEditingController(text: '1000');
    final minutesCtrl = TextEditingController(text: '1440');

    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Вся Кыргызская Республика'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Ваши товары будут доступны для заказа из любой точки КР.', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 16),
        TextField(controller: feeCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Стоимость доставки', suffixText: 'сом')),
        const SizedBox(height: 8),
        TextField(controller: minCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Мин. заказ', suffixText: 'сом')),
        const SizedBox(height: 8),
        TextField(controller: minutesCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Время доставки', suffixText: 'мин')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Добавить')),
      ],
    ));

    if (confirmed == true) {
      await _supabase.from('delivery_zones').insert({
        'warehouse_id': _warehouseId, 'company_id': _companyId, 'zone_type': 'country',
        'name': 'Вся Кыргызская Республика 🇰🇬', 'geo_name': 'KG',
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
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Удалить зону?'),
      content: Text('Зона "${zone['name']}" будет удалена.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
      ],
    ));

    if (confirmed == true) {
      await _supabase.from('delivery_zones').delete().eq('id', zone['id']);
      _loadZones();
      if (mounted) showInfoSnackBar(context, null, 'Зона удалена');
    }
  }

  IconData _transportIcon(String type) {
    switch (type) {
      case 'bicycle': return Icons.pedal_bike;
      case 'motorcycle': return Icons.two_wheeler;
      case 'truck': return Icons.local_shipping;
      default: return Icons.delivery_dining;
    }
  }
}

// ═══════════════════════════════════════
// Dialogs
// ═══════════════════════════════════════

class _RadiusZoneDialog extends StatefulWidget {
  @override
  State<_RadiusZoneDialog> createState() => _RadiusZoneDialogState();
}

class _RadiusZoneDialogState extends State<_RadiusZoneDialog> {
  final _nameCtrl = TextEditingController(text: 'Зона доставки');
  final _radiusCtrl = TextEditingController(text: '5');
  final _feeCtrl = TextEditingController(text: '100');
  final _freeFromCtrl = TextEditingController(text: '500');
  final _minOrderCtrl = TextEditingController(text: '0');
  final _minutesCtrl = TextEditingController(text: '60');
  Map<String, dynamic>? _selectedCity;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.radar_rounded, color: Colors.blue, size: 22), SizedBox(width: 8), Text('Зона по радиусу'),
      ]),
      content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Название зоны')),
          const SizedBox(height: 12),
          const Text('Центр зоны', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: _kgCities.take(8).map((city) {
            final isSelected = _selectedCity?['id'] == city['id'];
            return ChoiceChip(
              label: Text(city['name'] as String, style: const TextStyle(fontSize: 12)),
              selected: isSelected, selectedColor: Colors.blue.withValues(alpha: 0.15),
              onSelected: (v) => setState(() {
                _selectedCity = v ? city : null;
                if (v) _nameCtrl.text = '${city['name']} (${_radiusCtrl.text} км)';
              }),
            );
          }).toList()),
          const SizedBox(height: 12),
          TextField(controller: _radiusCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Радиус (км)', suffixText: 'км'),
            onChanged: (v) { if (_selectedCity != null) _nameCtrl.text = '${_selectedCity!['name']} ($v км)'; }),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _feeCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Стоимость', suffixText: 'сом'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _freeFromCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Бесплатно от', suffixText: 'сом'))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _minOrderCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Мин. заказ', suffixText: 'сом'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _minutesCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Время', suffixText: 'мин'))),
          ]),
        ],
      ))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          onPressed: _selectedCity == null ? null : () => Navigator.pop(context, {
            'name': _nameCtrl.text, 'lat': _selectedCity!['lat'], 'lng': _selectedCity!['lng'],
            'radius': double.tryParse(_radiusCtrl.text) ?? 5, 'fee': double.tryParse(_feeCtrl.text) ?? 0,
            'free_from': double.tryParse(_freeFromCtrl.text) ?? 0, 'min_order': double.tryParse(_minOrderCtrl.text) ?? 0,
            'minutes': int.tryParse(_minutesCtrl.text) ?? 60,
          }),
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}

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
      title: const Row(children: [
        Icon(Icons.location_city_rounded, color: Colors.green, size: 22), SizedBox(width: 8), Text('Выберите города'),
      ]),
      content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Города доставки', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: _kgCities.map((city) {
            final cityName = city['name'] as String;
            return FilterChip(
              label: Text(cityName, style: const TextStyle(fontSize: 12)),
              selected: _selectedCities.contains(cityName),
              selectedColor: Colors.green.withValues(alpha: 0.15), checkmarkColor: Colors.green,
              onSelected: (v) => setState(() { if (v) { _selectedCities.add(cityName); } else { _selectedCities.remove(cityName); } }),
            );
          }).toList()),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(controller: _feeCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Стоимость', suffixText: 'сом'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _freeFromCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Бесплатно от', suffixText: 'сом'))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _minOrderCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Мин. заказ', suffixText: 'сом'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _minutesCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Время', suffixText: 'мин'))),
          ]),
        ],
      ))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          onPressed: _selectedCities.isEmpty ? null : () {
            final firstCity = _kgCities.firstWhere((c) => c['name'] == _selectedCities.first);
            Navigator.pop(context, {
              'name': _selectedCities.first, 'lat': firstCity['lat'], 'lng': firstCity['lng'],
              'cities': _selectedCities.toList(), 'fee': double.tryParse(_feeCtrl.text) ?? 0,
              'free_from': double.tryParse(_freeFromCtrl.text) ?? 0, 'min_order': double.tryParse(_minOrderCtrl.text) ?? 0,
              'minutes': int.tryParse(_minutesCtrl.text) ?? 90,
            });
          },
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}
