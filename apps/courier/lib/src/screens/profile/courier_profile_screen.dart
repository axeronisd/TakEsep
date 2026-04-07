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
  List<Map<String, dynamic>> _invitations = [];
  List<Map<String, dynamic>> _linkedWarehouses = [];
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

      // Stats
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

        // Load linked warehouses
        final links = await _supabase
            .from('courier_warehouse')
            .select('*, warehouses(name)')
            .eq('courier_id', courier['id'])
            .eq('is_active', true);
        _linkedWarehouses = List<Map<String, dynamic>>.from(links);
      }

      // Load pending invitations by phone
      if (user.phone != null) {
        final invites = await _supabase
            .from('courier_invitations')
            .select('*, warehouses(name)')
            .eq('phone', user.phone!)
            .eq('status', 'pending');
        _invitations = List<Map<String, dynamic>>.from(invites);
      }

      setState(() {
        _courier = courier;
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Profile load error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _acceptInvitation(Map<String, dynamic> invitation) async {
    if (_courier == null) return;
    try {
      final courierId = _courier!['id'];
      final warehouseId = invitation['warehouse_id'];

      // Обновить приглашение
      await _supabase.from('courier_invitations').update({
        'status': 'accepted',
        'courier_id': courierId,
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', invitation['id']);

      // Создать связь courier_warehouse
      await _supabase.from('courier_warehouse').upsert({
        'courier_id': courierId,
        'warehouse_id': warehouseId,
        'is_active': true,
      });

      // Обновить тип курьера на 'store'
      await _supabase.from('couriers').update({
        'courier_type': 'store',
      }).eq('id', courierId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Приглашение принято! 🎉'), backgroundColor: Colors.green),
        );
      }
      _loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _declineInvitation(Map<String, dynamic> invitation) async {
    try {
      await _supabase.from('courier_invitations').update({
        'status': 'declined',
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', invitation['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Приглашение отклонено'), backgroundColor: Colors.orange),
        );
      }
      _loadProfile();
    } catch (e) {
      debugPrint('Decline error: $e');
    }
  }

  Future<void> _leaveWarehouse(Map<String, dynamic> link) async {
    final warehouseName = link['warehouses']?['name'] ?? 'Магазин';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Покинуть магазин?'),
        content: Text(
          'Вы перестанете получать приоритетные заказы от "$warehouseName". '
          'Вы останетесь фрилансером в системе AkJol.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Остаться'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Покинуть'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('courier_warehouse').update({
          'is_active': false,
          'left_at': DateTime.now().toIso8601String(),
        }).eq('id', link['id']);

        // Если больше нет привязок — вернуть тип на freelance
        final remaining = await _supabase
            .from('courier_warehouse')
            .select('id')
            .eq('courier_id', _courier!['id'])
            .eq('is_active', true);

        if (remaining.isEmpty) {
          await _supabase.from('couriers').update({
            'courier_type': 'freelance',
          }).eq('id', _courier!['id']);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Вы покинули "$warehouseName"'), backgroundColor: Colors.orange),
          );
        }
        _loadProfile();
      } catch (e) {
        debugPrint('Leave error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
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
                      child: const Icon(Icons.delivery_dining, size: 40, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      _courier?['name'] ?? 'Курьер',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Center(
                    child: Text(
                      user?.phone ?? '',
                      style: TextStyle(fontSize: 14, color: AkJolTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: (_courier?['courier_type'] == 'store'
                                ? Colors.blue
                                : Colors.orange)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _courier?['courier_type'] == 'store' ? '🏪 Штатный курьер' : '🌍 Фрилансер',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _courier?['courier_type'] == 'store' ? Colors.blue : Colors.orange,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Pending Invitations ──
                  if (_invitations.isNotEmpty) ...[
                    const Text('📬 Приглашения',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ..._invitations.map((inv) {
                      final storeName = inv['warehouses']?['name'] ?? 'Магазин';
                      return Card(
                        color: Colors.green.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.storefront, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(storeName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700, fontSize: 15)),
                                ),
                              ]),
                              const SizedBox(height: 6),
                              Text(
                                'Магазин приглашает вас стать штатным курьером. '
                                'Вы будете получать заказы первым!',
                                style: TextStyle(fontSize: 13, color: AkJolTheme.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _declineInvitation(inv),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                    ),
                                    child: const Text('Отклонить'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _acceptInvitation(inv),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('Принять'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],

                  // ── Linked Warehouses ──
                  if (_linkedWarehouses.isNotEmpty) ...[
                    const Text('🏪 Мои магазины',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ..._linkedWarehouses.map((link) {
                      final name = link['warehouses']?['name'] ?? 'Магазин';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.storefront, color: Colors.blue),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Штатный курьер',
                              style: TextStyle(fontSize: 12, color: Colors.blue)),
                          trailing: TextButton(
                            onPressed: () => _leaveWarehouse(link),
                            child: const Text('Покинуть',
                                style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],

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
                        subtitle: Text(_transportLabel(_courier!['transport_type'] ?? '')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: Icon(
                          _courier!['is_online'] == true ? Icons.circle : Icons.circle_outlined,
                          color: _courier!['is_online'] == true ? Colors.green : Colors.grey,
                          size: 16,
                        ),
                        title: Text(_courier!['is_online'] == true ? 'Онлайн' : 'Оффлайн'),
                        subtitle: Text(
                          _courier!['is_active'] == true ? 'Аккаунт активен' : 'Аккаунт отключен',
                          style: TextStyle(
                            color: _courier!['is_active'] == true ? AkJolTheme.success : AkJolTheme.error,
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
                    label: const Text('Выйти', style: TextStyle(color: AkJolTheme.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AkJolTheme.error),
                    ),
                  ),
                ],
              ),
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: AkJolTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
