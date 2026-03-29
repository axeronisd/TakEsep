import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CourierManagementScreen extends StatefulWidget {
  final String warehouseId;
  const CourierManagementScreen({super.key, required this.warehouseId});

  @override
  State<CourierManagementScreen> createState() =>
      _CourierManagementScreenState();
}

class _CourierManagementScreenState extends State<CourierManagementScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _couriers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCouriers();
  }

  Future<void> _loadCouriers() async {
    try {
      final data = await _supabase
          .from('couriers')
          .select('*')
          .eq('warehouse_id', widget.warehouseId)
          .order('created_at');

      setState(() {
        _couriers = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои курьеры')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _couriers.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadCouriers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _couriers.length,
                    itemBuilder: (_, i) => _CourierCard(
                      courier: _couriers[i],
                      onToggle: () => _toggleCourier(_couriers[i]),
                      onDelete: () => _deleteCourier(_couriers[i]),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCourierDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Добавить курьера'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delivery_dining, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Нет курьеров',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500])),
          const SizedBox(height: 8),
          Text('Добавьте курьера для доставки заказов',
              style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }

  void _showAddCourierDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String transport = 'bicycle';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Новый курьер'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Имя',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Телефон',
                  prefixIcon: Icon(Icons.phone),
                  prefixText: '+996 ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: transport,
                decoration: const InputDecoration(
                  labelText: 'Транспорт',
                  prefixIcon: Icon(Icons.directions_bike),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'bicycle', child: Text('Велосипед')),
                  DropdownMenuItem(
                      value: 'motorcycle', child: Text('Мотоцикл')),
                  DropdownMenuItem(
                      value: 'truck', child: Text('Грузовой (Муравей)')),
                ],
                onChanged: (v) =>
                    setDialogState(() => transport = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    phoneController.text.isEmpty) return;

                await _supabase.from('couriers').insert({
                  'warehouse_id': widget.warehouseId,
                  'name': nameController.text,
                  'phone': '+996${phoneController.text}',
                  'transport_type': transport,
                });

                if (context.mounted) Navigator.pop(context);
                _loadCouriers();
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleCourier(Map<String, dynamic> courier) async {
    await _supabase.from('couriers').update({
      'is_active': !(courier['is_active'] ?? true),
    }).eq('id', courier['id']);
    _loadCouriers();
  }

  Future<void> _deleteCourier(Map<String, dynamic> courier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить курьера?'),
        content: Text('${courier['name']} будет удалён'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _supabase.from('couriers').delete().eq('id', courier['id']);
      _loadCouriers();
    }
  }
}

class _CourierCard extends StatelessWidget {
  final Map<String, dynamic> courier;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _CourierCard({
    required this.courier,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = courier['name'] ?? '';
    final phone = courier['phone'] ?? '';
    final transport = courier['transport_type'] ?? 'bicycle';
    final isActive = courier['is_active'] ?? true;
    final isOnline = courier['is_online'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isOnline
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _transportIcon(transport),
                color: isOnline ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  Text(phone,
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[500])),
                  Text(
                    '${_transportLabel(transport)} • ${isActive ? "Активен" : "Отключён"}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),

            // Actions
            PopupMenuButton(
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: onToggle,
                  child: Row(
                    children: [
                      Icon(isActive ? Icons.block : Icons.check_circle,
                          size: 18),
                      const SizedBox(width: 8),
                      Text(isActive ? 'Отключить' : 'Включить'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  onTap: onDelete,
                  child: const Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Удалить', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
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
