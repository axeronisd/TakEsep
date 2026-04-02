import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';
import '../../providers/location_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _nearbyStores = [];
  List<Map<String, dynamic>> _allStores = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAllStores();
  }

  Future<void> _loadAllStores() async {
    try {
      final data = await _supabase
          .from('delivery_settings')
          .select('*, warehouses(name)')
          .eq('is_active', true);

      setState(() {
        _allStores = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  /// Фильтрует магазины по зонам доставки и местоположению
  Future<List<Map<String, dynamic>>> _findNearbyStores(double lat, double lng) async {
    try {
      final result = await _supabase.rpc('find_businesses_near', params: {
        'p_lat': lat,
        'p_lng': lng,
      });

      if (result is List) {
        return List<Map<String, dynamic>>.from(
          result.map((r) => r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{}),
        );
      }
    } catch (e) {
      debugPrint('⚠️ find_businesses_near error: $e');
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(locationProvider);

    // Когда локация определена — грузим ближайшие магазины
    if (location.hasLocation && _nearbyStores.isEmpty && !_loading) {
      _findNearbyStores(location.lat!, location.lng!).then((stores) {
        if (mounted) setState(() => _nearbyStores = stores);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // ─── AppBar с локацией ─────────────────
          SliverAppBar(
            floating: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: GestureDetector(
              onTap: () => _showCityPicker(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: AkJolTheme.primary, size: 20),
                  const SizedBox(width: 6),
                  if (location.loading)
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AkJolTheme.primary),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.cityName ?? 'Определяем...',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        if (location.error != null)
                          Text(
                            location.error!,
                            style: const TextStyle(fontSize: 10, color: Colors.red),
                          ),
                      ],
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 18, color: AkJolTheme.textSecondary),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.my_location_rounded, size: 20),
                tooltip: 'Определить снова',
                onPressed: () => ref.read(locationProvider.notifier).determinePosition(),
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _showSearch(context),
              ),
            ],
          ),

          // ─── Поиск по магазинам ────────────────
          if (_searchQuery.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Text('Поиск: "$_searchQuery"',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _searchQuery = ''),
                      child: const Text('Очистить'),
                    ),
                  ],
                ),
              ),
            ),

          // ─── Ближайшие магазины ────────────────
          if (_nearbyStores.isNotEmpty && _searchQuery.isEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AkJolTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.near_me, size: 14, color: AkJolTheme.primary),
                          SizedBox(width: 4),
                          Text('Доставка доступна',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AkJolTheme.primary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${_nearbyStores.length} магазинов',
                        style: TextStyle(fontSize: 13, color: AkJolTheme.textTertiary)),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, idx) {
                  final zone = _nearbyStores[idx];
                  // Найдём соответствующий магазин из allStores
                  final warehouseId = zone['warehouse_id'];
                  final store = _allStores.cast<Map<String, dynamic>?>().firstWhere(
                    (s) => s?['warehouse_id'] == warehouseId,
                    orElse: () => null,
                  );
                  return _StoreCard(
                    store: store,
                    zone: zone,
                    canOrder: true,
                    onTap: () => context.go('/store/$warehouseId'),
                  );
                },
                childCount: _nearbyStores.length,
              ),
            ),
          ],

          // ─── Все магазины / результаты поиска ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                _searchQuery.isNotEmpty ? 'Результаты' : 'Все магазины',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, idx) {
                  final filtered = _getFilteredStores();
                  if (idx >= filtered.length) return null;
                  final store = filtered[idx];
                  final warehouseId = store['warehouse_id'];
                  // Проверяем есть ли этот магазин в зоне доставки
                  final zone = _nearbyStores.cast<Map<String, dynamic>?>().firstWhere(
                    (z) => z?['warehouse_id'] == warehouseId,
                    orElse: () => null,
                  );
                  final canOrder = zone != null;

                  return _StoreCard(
                    store: store,
                    zone: zone,
                    canOrder: canOrder,
                    onTap: () => context.go('/store/$warehouseId'),
                  );
                },
                childCount: _getFilteredStores().length,
              ),
            ),

          // Пустое состояние
          if (!_loading && _allStores.isEmpty)
            SliverFillRemaining(child: _buildEmptyState()),

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredStores() {
    if (_searchQuery.isEmpty) return _allStores;
    final q = _searchQuery.toLowerCase();
    return _allStores.where((s) {
      final name = (s['warehouses']?['name'] ?? '').toString().toLowerCase();
      final desc = (s['description'] ?? '').toString().toLowerCase();
      return name.contains(q) || desc.contains(q);
    }).toList();
  }

  void _showSearch(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: _searchQuery);
        return AlertDialog(
          title: const Text('Поиск магазинов'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Название магазина...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                setState(() => _searchQuery = ctrl.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Искать'),
            ),
          ],
        );
      },
    );
  }

  void _showCityPicker(BuildContext context) {
    const cities = [
      {'name': 'Бишкек',       'lat': 42.8746, 'lng': 74.5698},
      {'name': 'Ош',           'lat': 40.5333, 'lng': 72.8000},
      {'name': 'Джалал-Абад',  'lat': 40.9333, 'lng': 73.0000},
      {'name': 'Каракол',      'lat': 42.4903, 'lng': 78.3936},
      {'name': 'Токмок',       'lat': 42.7667, 'lng': 75.3000},
      {'name': 'Балыкчы',      'lat': 42.4600, 'lng': 76.1900},
      {'name': 'Нарын',        'lat': 41.4300, 'lng': 76.0000},
      {'name': 'Талас',        'lat': 42.5200, 'lng': 72.2400},
      {'name': 'Баткен',       'lat': 40.0600, 'lng': 70.8200},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Выберите город',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Покажем магазины с доставкой в вашем городе',
                style: TextStyle(fontSize: 13, color: AkJolTheme.textSecondary)),
            const SizedBox(height: 16),

            // Кнопка геолокации
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AkJolTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.my_location, color: AkJolTheme.primary, size: 20),
              ),
              title: const Text('Определить автоматически',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('По GPS'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(locationProvider.notifier).determinePosition();
                setState(() => _nearbyStores = []);
              },
            ),
            const Divider(),

            // Города
            ...cities.map((city) => ListTile(
                  leading: const Icon(Icons.location_city, color: AkJolTheme.textSecondary),
                  title: Text(city['name'] as String),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(locationProvider.notifier).setCity(
                      city['name'] as String,
                      city['lat'] as double,
                      city['lng'] as double,
                    );
                    setState(() => _nearbyStores = []);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_outlined,
              size: 64, color: AkJolTheme.textTertiary),
          const SizedBox(height: 16),
          Text('Нет магазинов',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AkJolTheme.textSecondary)),
          const SizedBox(height: 8),
          Text('Пока нет магазинов в AkJol',
              style: TextStyle(color: AkJolTheme.textTertiary)),
        ],
      ),
    );
  }
}

/// Карточка магазина
class _StoreCard extends StatelessWidget {
  final Map<String, dynamic>? store;
  final Map<String, dynamic>? zone;
  final bool canOrder;
  final VoidCallback onTap;

  const _StoreCard({
    required this.store,
    this.zone,
    required this.canOrder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = store?['warehouses']?['name'] ?? 'Магазин';
    final desc = store?['description'] ?? '';
    final zoneName = zone?['zone_name'] ?? '';
    final distance = zone?['distance_km'] ?? 0;
    final fee = (zone?['delivery_fee'] as num?)?.toDouble() ?? 0;
    final freeFrom = (zone?['free_delivery_from'] as num?)?.toDouble() ?? 0;
    final minutes = zone?['estimated_minutes'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: canOrder
              ? AkJolTheme.primary.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Иконка магазина
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: canOrder
                      ? AkJolTheme.primary.withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: canOrder ? AkJolTheme.primary : Colors.grey,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),

              // Информация
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    if (desc.toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(desc.toString(),
                          style: TextStyle(fontSize: 12, color: AkJolTheme.textSecondary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 6),
                    if (canOrder)
                      Row(
                        children: [
                          if (distance > 0) _badge('📍 ${distance} км', AkJolTheme.primary),
                          if (minutes > 0) ...[
                            const SizedBox(width: 6),
                            _badge('⏱ ${_formatTime(minutes)}', Colors.orange),
                          ],
                          if (fee > 0) ...[
                            const SizedBox(width: 6),
                            _badge(
                              freeFrom > 0
                                  ? '🚚 ${fee.toInt()} сом (бесп. от ${freeFrom.toInt()})'
                                  : '🚚 ${fee.toInt()} сом',
                              Colors.green,
                            ),
                          ],
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '🔍 Каталог доступен • Доставка не в вашем районе',
                          style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              ),

              Icon(Icons.chevron_right,
                  color: canOrder ? AkJolTheme.textSecondary : Colors.grey.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }

  String _formatTime(int minutes) {
    if (minutes >= 1440) return '${(minutes / 1440).round()} д';
    if (minutes >= 60) return '${minutes ~/ 60}ч${minutes % 60 > 0 ? " ${minutes % 60}м" : ""}';
    return '${minutes}м';
  }
}
