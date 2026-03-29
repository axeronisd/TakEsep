import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';

class CourierProfileScreen extends StatefulWidget {
  const CourierProfileScreen({super.key});

  @override
  State<CourierProfileScreen> createState() => _CourierProfileScreenState();
}

class _CourierProfileScreenState extends State<CourierProfileScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _courier;
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final courier = await _supabase
          .from('couriers')
          .select('*, warehouses(name)')
          .eq('user_id', user.id)
          .maybeSingle();

      // Get stats
      Map<String, dynamic>? stats;
      if (courier != null) {
        final deliveredOrders = await _supabase
            .from('delivery_orders')
            .select('id, courier_earning')
            .eq('courier_id', courier['id'])
            .eq('status', 'delivered');

        double totalEarned = 0;
        for (final o in deliveredOrders) {
          totalEarned += (o['courier_earning'] as num?)?.toDouble() ?? 0;
        }

        stats = {
          'total_orders': deliveredOrders.length,
          'total_earned': totalEarned,
        };
      }

      setState(() {
        _courier = courier;
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Avatar
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AkJolTheme.primaryDark, AkJolTheme.primary],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delivery_dining,
                        size: 40, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _courier?['name'] ?? 'Курьер',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                Center(
                  child: Text(
                    user?.phone ?? '',
                    style: TextStyle(
                        fontSize: 14, color: AkJolTheme.textSecondary),
                  ),
                ),
                if (_courier?['warehouses']?['name'] != null)
                  Center(
                    child: Chip(
                      avatar: const Icon(Icons.storefront, size: 16),
                      label: Text(_courier!['warehouses']['name']),
                    ),
                  ),
                const SizedBox(height: 24),

                // Stats
                if (_stats != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.check_circle,
                          label: 'Доставок',
                          value: '${_stats!['total_orders']}',
                          color: AkJolTheme.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.account_balance_wallet,
                          label: 'Заработано',
                          value:
                              '${(_stats!['total_earned'] as double).toStringAsFixed(0)} сом',
                          color: AkJolTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Transport info
                if (_courier != null) ...[
                  Card(
                    child: ListTile(
                      leading: Icon(
                        _transportIcon(_courier!['transport_type'] ?? ''),
                        color: AkJolTheme.primary,
                      ),
                      title: const Text('Транспорт'),
                      subtitle: Text(
                          _transportLabel(_courier!['transport_type'] ?? '')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        _courier!['is_online'] == true
                            ? Icons.circle
                            : Icons.circle_outlined,
                        color: _courier!['is_online'] == true
                            ? Colors.green
                            : Colors.grey,
                        size: 16,
                      ),
                      title: Text(
                        _courier!['is_online'] == true
                            ? 'Онлайн'
                            : 'Оффлайн',
                      ),
                      subtitle: Text(
                        _courier!['is_active'] == true
                            ? 'Аккаунт активен'
                            : 'Аккаунт отключен',
                        style: TextStyle(
                          color: _courier!['is_active'] == true
                              ? AkJolTheme.success
                              : AkJolTheme.error,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Logout
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: AkJolTheme.error),
                  label: const Text('Выйти',
                      style: TextStyle(color: AkJolTheme.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AkJolTheme.error),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) context.go('/login');
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

  String _transportLabel(String type) {
    switch (type) {
      case 'bicycle':
        return 'Велосипед';
      case 'motorcycle':
        return 'Мотоцикл';
      case 'truck':
        return 'Грузовой';
      default:
        return type;
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: AkJolTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
