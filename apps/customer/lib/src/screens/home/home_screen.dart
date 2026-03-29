import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _stores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    try {
      final data = await _supabase
          .from('delivery_settings')
          .select('*, warehouses(name)')
          .eq('is_active', true);

      setState(() {
        _stores = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: AkJolTheme.primary, size: 20),
            SizedBox(width: 6),
            Text('AkJol'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {/* TODO: search */},
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stores.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadStores,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Header
                      const Text(
                        'Магазины рядом',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_stores.length} доступно для доставки',
                        style: TextStyle(
                          color: AkJolTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Store cards
                      ..._stores.map((store) => _StoreCard(
                            store: store,
                            onTap: () {
                              context.go('/store/${store['warehouse_id']}');
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
          Text(
            'Нет магазинов рядом',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AkJolTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Попробуйте позже или измените адрес',
            style: TextStyle(color: AkJolTheme.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final VoidCallback onTap;

  const _StoreCard({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name =
        store['warehouses']?['name'] ?? 'Магазин';
    final desc = store['description'] ?? '';
    final radius = store['delivery_radius_km'] ?? 3;
    final transports = List<String>.from(store['available_transports'] ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Store icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AkJolTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.storefront,
                    color: AkJolTheme.primary, size: 28),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 13,
                          color: AkJolTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: AkJolTheme.textTertiary),
                        const SizedBox(width: 2),
                        Text(
                          'до ${radius} км',
                          style: TextStyle(
                              fontSize: 12, color: AkJolTheme.textTertiary),
                        ),
                        const SizedBox(width: 12),
                        ...transports.map((t) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                _transportIcon(t),
                                size: 14,
                                color: AkJolTheme.textTertiary,
                              ),
                            )),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AkJolTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  IconData _transportIcon(String type) {
    switch (type) {
      case 'bicycle':
        return Icons.pedal_bike;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'truck':
        return Icons.local_shipping;
      default:
        return Icons.delivery_dining;
    }
  }
}
