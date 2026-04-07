import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();

  List<Map<String, dynamic>> _orders = [];
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
      final customer = await _supabase
          .from('customers')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final orders = await _supabase
          .from('delivery_orders')
          .select('*, warehouses(name)')
          .eq('customer_id', user.id)
          .order('created_at', ascending: false)
          .limit(20);

      setState(() {
        _nameController.text = customer?['name'] ?? '';
        _orders = List<Map<String, dynamic>>.from(orders);
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
                      color: AkJolTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person,
                        size: 40, color: AkJolTheme.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    user?.phone ?? '',
                    style: TextStyle(
                        fontSize: 16, color: AkJolTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 24),

                // Name
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Ваше имя',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _saveName,
                  child: const Text('Сохранить'),
                ),
                const SizedBox(height: 32),

                // Orders
                Row(
                  children: [
                    const Text('Мои заказы',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${_orders.length}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AkJolTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 12),

                if (_orders.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long,
                              size: 48, color: AkJolTheme.textTertiary),
                          const SizedBox(height: 8),
                          Text('Нет заказов',
                              style: TextStyle(
                                  color: AkJolTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),

                ..._orders.map((order) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _statusColor(order['status'])
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _statusIcon(order['status']),
                            color: _statusColor(order['status']),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          order['warehouses']?['name'] ?? 'Заказ',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          '${order['order_number']} • ${_statusLabel(order['status'])}',
                          style: TextStyle(
                              fontSize: 12, color: AkJolTheme.textTertiary),
                        ),
                        trailing: Text(
                          '${((order['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)} сом',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () {
                          // Navigate to order tracking
                          context.push('/order/${order['id']}');
                        },
                      ),
                    )),

                const SizedBox(height: 24),

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

  Future<void> _saveName() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('customers').upsert({
        'id': user.id,
        'name': _nameController.text,
        'phone': user.phone,
      }, onConflict: 'id');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Имя сохранено'),
            backgroundColor: AkJolTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AkJolTheme.error),
        );
      }
    }
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) context.go('/login');
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'assembling':
        return Colors.blue;
      case 'ready':
        return Colors.indigo;
      case 'courier_assigned':
        return Colors.purple;
      case 'picked_up':
        return Colors.teal;
      case 'delivered':
        return AkJolTheme.success;
      default:
        if (status?.startsWith('cancelled') == true) return AkJolTheme.error;
        return Colors.grey;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'assembling':
        return Icons.inventory_2;
      case 'ready':
        return Icons.done;
      case 'courier_assigned':
        return Icons.delivery_dining;
      case 'picked_up':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      default:
        if (status?.startsWith('cancelled') == true) return Icons.cancel;
        return Icons.receipt;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'Ожидает';
      case 'confirmed':
        return 'Принят';
      case 'assembling':
        return 'Собирается';
      case 'ready':
        return 'Готов';
      case 'courier_assigned':
        return 'Курьер назначен';
      case 'picked_up':
        return 'В пути';
      case 'delivered':
        return 'Доставлен';
      case 'cancelled_by_customer':
      case 'cancelled_by_customer_late':
        return 'Отменён вами';
      case 'cancelled_by_store':
        return 'Отменён магазином';
      case 'cancelled_by_courier':
        return 'Курьер отменил';
      case 'cancelled_no_courier':
        return 'Нет курьеров';
      default:
        return status ?? '';
    }
  }
}
