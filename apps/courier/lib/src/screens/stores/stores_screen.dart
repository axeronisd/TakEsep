import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/courier_providers.dart';
import '../../theme/akjol_theme.dart';

/// ═══════════════════════════════════════════════════════════════
/// Stores Screen — Список магазинов/складов для курьера
///
/// Показывает все активные склады, привязанные выделяются.
/// Курьер может открыть навигацию к складу.
/// ═══════════════════════════════════════════════════════════════

class StoresScreen extends ConsumerStatefulWidget {
  const StoresScreen({super.key});

  @override
  ConsumerState<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends ConsumerState<StoresScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _stores = [];
  bool _loading = true;
  String _filter = 'all'; // 'all' or 'my'

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('warehouses')
          .select('id, name, address, latitude, longitude, organization_id, companies(title)')
          .order('name');

      setState(() {
        _stores = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredStores {
    if (_filter == 'my') {
      final myIds = ref.read(courierWarehouseIdsProvider);
      return _stores.where((s) => myIds.contains(s['id'])).toList();
    }
    return _stores;
  }

  @override
  Widget build(BuildContext context) {
    final myWarehouseIds = ref.watch(courierWarehouseIdsProvider);
    final filtered = _filteredStores;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Магазины'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('Все')),
                ButtonSegment(value: 'my', label: Text('Мои')),
              ],
              selected: {_filter},
              onSelectionChanged: (v) => setState(() => _filter = v.first),
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadStores,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _StoreCard(
                      store: filtered[i],
                      isMine: myWarehouseIds.contains(filtered[i]['id']),
                      onNavigate: () => _navigateToStore(filtered[i]),
                      onCall: () => _callStore(filtered[i]),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AkJolTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront, size: 40, color: AkJolTheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            _filter == 'my' ? 'Нет привязанных магазинов' : 'Нет магазинов',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AkJolTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            _filter == 'my'
                ? 'Администратор привяжет вас к магазинам'
                : 'Магазины появятся когда бизнесы зарегистрируются',
            style: TextStyle(color: AkJolTheme.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _navigateToStore(Map<String, dynamic> store) {
    final lat = (store['latitude'] as num?)?.toDouble();
    final lng = (store['longitude'] as num?)?.toDouble();
    final address = store['address'] ?? '';

    if (lat != null && lng != null) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Навигация к ${store['name']}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _NavOption(
                  icon: Icons.map, label: '2ГИС', color: AkJolTheme.primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _launch('https://2gis.kg/bishkek/geo/$lng,$lat');
                  },
                ),
                _NavOption(
                  icon: Icons.directions, label: 'Google Maps', color: Colors.blue,
                  onTap: () {
                    Navigator.pop(ctx);
                    _launch('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
                  },
                ),
                _NavOption(
                  icon: Icons.navigation, label: 'Яндекс', color: Colors.red,
                  onTap: () {
                    Navigator.pop(ctx);
                    _launch('yandexnavi://build_route_on_map?lat_to=$lat&lon_to=$lng');
                  },
                ),
              ],
            ),
          ),
        ),
      );
    } else if (address.isNotEmpty) {
      _launch('https://www.google.com/maps/search/${Uri.encodeComponent(address)}');
    }
  }

  void _callStore(Map<String, dynamic> store) {
    // Could add phone field to warehouses in the future
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Контакт магазина не указан')),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

// ═══════════════════════════════════════════════════════════════
// STORE CARD
// ═══════════════════════════════════════════════════════════════

class _StoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final bool isMine;
  final VoidCallback onNavigate;
  final VoidCallback onCall;

  const _StoreCard({
    required this.store,
    required this.isMine,
    required this.onNavigate,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final name = store['name'] ?? 'Склад';
    final address = store['address'] ?? '';
    final companyName = store['companies']?['title'] ?? '';
    final hasCoords = store['latitude'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isMine
            ? BorderSide(color: AkJolTheme.primary.withValues(alpha: 0.4), width: 1.5)
            : const BorderSide(color: AkJolTheme.border),
      ),
      child: InkWell(
        onTap: hasCoords ? onNavigate : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: isMine
                      ? AkJolTheme.primary.withValues(alpha: 0.12)
                      : AkJolTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: isMine ? AkJolTheme.primary : AkJolTheme.textTertiary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                        if (isMine)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AkJolTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Мой',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AkJolTheme.primary)),
                          ),
                      ],
                    ),
                    if (address.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: AkJolTheme.textTertiary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(address,
                                  style: TextStyle(
                                      fontSize: 13, color: AkJolTheme.textSecondary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    if (companyName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(companyName,
                            style: TextStyle(
                                fontSize: 12, color: AkJolTheme.textTertiary)),
                      ),
                  ],
                ),
              ),

              // Navigate button
              if (hasCoords)
                IconButton(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.navigation_rounded,
                      color: AkJolTheme.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavOption({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}
