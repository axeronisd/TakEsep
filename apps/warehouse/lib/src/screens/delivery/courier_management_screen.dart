import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CourierManagementScreen extends StatefulWidget {
  final String warehouseId;
  const CourierManagementScreen({super.key, required this.warehouseId});

  @override
  State<CourierManagementScreen> createState() =>
      _CourierManagementScreenState();
}

class _CourierManagementScreenState extends State<CourierManagementScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabCtrl;

  List<Map<String, dynamic>> _couriers = [];
  List<Map<String, dynamic>> _invitations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await Future.wait([_loadCouriers(), _loadInvitations()]);
    setState(() => _loading = false);
  }

  Future<void> _loadCouriers() async {
    try {
      // Загружаем курьеров, привязанных к этому складу через courier_warehouse
      final linked = await _supabase
          .from('courier_warehouse')
          .select('*, couriers(*)')
          .eq('warehouse_id', widget.warehouseId)
          .eq('is_active', true);

      // Также загружаем старых курьеров напрямую привязанных (legacy)
      final direct = await _supabase
          .from('couriers')
          .select('*')
          .eq('warehouse_id', widget.warehouseId)
          .order('created_at');

      // Совмещаем оба списка, убирая дубликаты
      final allIds = <String>{};
      final merged = <Map<String, dynamic>>[];
      
      for (final row in linked) {
        final courier = row['couriers'] as Map<String, dynamic>?;
        if (courier != null && allIds.add(courier['id'])) {
          courier['_linked'] = true; // маркер что через courier_warehouse
          merged.add(courier);
        }
      }
      for (final c in direct) {
        if (allIds.add(c['id'])) {
          merged.add(Map<String, dynamic>.from(c));
        }
      }

      _couriers = merged;
    } catch (e) {
      debugPrint('Load couriers: $e');
    }
  }

  Future<void> _loadInvitations() async {
    try {
      final data = await _supabase
          .from('courier_invitations')
          .select('*')
          .eq('warehouse_id', widget.warehouseId)
          .order('created_at', ascending: false);
      _invitations = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Load invitations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        _invitations.where((i) => i['status'] == 'pending').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои курьеры'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.people, size: 18),
                const SizedBox(width: 6),
                Text('Курьеры (${_couriers.length})'),
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.mail_outline, size: 18),
                const SizedBox(width: 6),
                const Text('Приглашения'),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('$pendingCount',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildCouriersTab(),
                _buildInvitationsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showInviteDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Добавить'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ═══════════════════════════════════════
  // TAB 1: Курьеры
  // ═══════════════════════════════════════
  Widget _buildCouriersTab() {
    if (_couriers.isEmpty) {
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
            Text('Пригласите курьера по номеру телефона',
                style: TextStyle(color: Colors.grey[400])),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _showInviteDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Пригласить'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _couriers.length,
        itemBuilder: (_, i) => _CourierCard(
          courier: _couriers[i],
          onToggle: () => _toggleCourier(_couriers[i]),
          onRemove: () => _removeCourier(_couriers[i]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // TAB 2: Приглашения
  // ═══════════════════════════════════════
  Widget _buildInvitationsTab() {
    if (_invitations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Нет приглашений',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500])),
            const SizedBox(height: 8),
            Text('Нажмите "Пригласить" чтобы отправить первое приглашение',
                style: TextStyle(color: Colors.grey[400]),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _invitations.length,
        itemBuilder: (_, i) {
          final inv = _invitations[i];
          final status = inv['status'] as String? ?? 'pending';
          final phone = inv['phone'] as String? ?? '';
          final createdAt = inv['created_at'] as String?;

          Color statusColor;
          String statusLabel;
          IconData statusIcon;
          switch (status) {
            case 'accepted':
              statusColor = Colors.green;
              statusLabel = 'Принято';
              statusIcon = Icons.check_circle;
            case 'declined':
              statusColor = Colors.red;
              statusLabel = 'Отклонено';
              statusIcon = Icons.cancel;
            default:
              statusColor = Colors.orange;
              statusLabel = 'Ожидает';
              statusIcon = Icons.hourglass_bottom;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor),
              ),
              title: Text(phone,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '$statusLabel • ${_formatDate(createdAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              trailing: status == 'pending'
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      tooltip: 'Отменить',
                      onPressed: () => _cancelInvitation(inv['id']),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════
  // Actions
  // ═══════════════════════════════════════

  void _showInviteDialog() {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String selectedTransport = 'bicycle';
    bool sending = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.person_add, color: Colors.green),
            SizedBox(width: 8),
            Text('Добавить курьера'),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Курьер получит мгновенный доступ к заказам вашего склада. '
                  'Если он уже зарегистрирован в AkJol — он будет привязан к вашему магазину.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),

                // Phone
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Номер телефона *',
                    prefixIcon: Icon(Icons.phone),
                    prefixText: '+996 ',
                    hintText: '550 123456',
                  ),
                ),
                const SizedBox(height: 12),

                // Name
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Имя курьера',
                    prefixIcon: Icon(Icons.person_outline),
                    hintText: 'Азамат',
                  ),
                ),
                const SizedBox(height: 12),

                // Transport type
                DropdownButtonFormField<String>(
                  value: selectedTransport,
                  decoration: const InputDecoration(
                    labelText: 'Транспорт',
                    prefixIcon: Icon(Icons.directions_bike),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'bicycle',
                      child: Text('Электровелосипед'),
                    ),
                    DropdownMenuItem(
                      value: 'motorcycle',
                      child: Text('Муравей'),
                    ),
                    DropdownMenuItem(
                      value: 'truck',
                      child: Text('Грузовой'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedTransport = v);
                    }
                  },
                ),

                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(errorText!,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton.icon(
              onPressed: sending
                  ? null
                  : () async {
                      final phone = phoneCtrl.text.replaceAll(' ', '');
                      if (phone.isEmpty || phone.length < 9) {
                        setDialogState(() => errorText = 'Введите корректный номер');
                        return;
                      }

                      setDialogState(() {
                        sending = true;
                        errorText = null;
                      });

                      try {
                        final result = await _supabase.rpc(
                          'rpc_invite_store_courier',
                          params: {
                            'p_phone': '+996$phone',
                            'p_name': nameCtrl.text.trim(),
                            'p_warehouse_id': widget.warehouseId,
                            'p_transport_type': selectedTransport,
                          },
                        );

                        if (context.mounted) {
                          Navigator.pop(context);

                          final action = result?['action'] ?? '';
                          final courierName =
                              result?['courier_name'] ?? 'Курьер';

                          String message;
                          if (action == 'ALREADY_LINKED') {
                            message = '$courierName уже привязан к вашему складу';
                          } else if (action.toString().startsWith('EXISTING')) {
                            message = '$courierName привязан к вашему складу ✓';
                          } else {
                            message = '$courierName добавлен и привязан ✓';
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(message),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                        _loadData();
                      } catch (e) {
                        setDialogState(() {
                          sending = false;
                          errorText = 'Ошибка: $e';
                        });
                      }
                    },
              icon: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add),
              label: Text(sending ? 'Добавление...' : 'Добавить'),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
    _loadData();
  }

  Future<void> _removeCourier(Map<String, dynamic> courier) async {
    final name = courier['name'] ?? 'Курьер';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Убрать курьера?'),
        content: Text(
            '$name будет убран из вашего магазина. Он останется фрилансером и сможет брать заказы из других магазинов.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Убрать'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Деактивируем связь в courier_warehouse
      try {
        await _supabase
            .from('courier_warehouse')
            .update({'is_active': false, 'left_at': DateTime.now().toIso8601String()})
            .eq('courier_id', courier['id'])
            .eq('warehouse_id', widget.warehouseId);
      } catch (_) {}

      // Убираем прямую привязку (legacy)
      try {
        await _supabase
            .from('couriers')
            .update({'warehouse_id': null})
            .eq('id', courier['id'])
            .eq('warehouse_id', widget.warehouseId);
      } catch (_) {}

      _loadData();
    }
  }

  Future<void> _cancelInvitation(String invitationId) async {
    await _supabase
        .from('courier_invitations')
        .delete()
        .eq('id', invitationId);
    _loadData();
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _CourierCard extends StatelessWidget {
  final Map<String, dynamic> courier;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  const _CourierCard({
    required this.courier,
    required this.onToggle,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name = courier['name'] ?? '';
    final phone = courier['phone'] ?? '';
    final transport = courier['transport_type'] ?? 'bicycle';
    final isActive = courier['is_active'] ?? true;
    final isOnline = courier['is_online'] ?? false;
    final courierType = courier['courier_type'] ?? 'freelance';

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
                      const SizedBox(width: 6),
                      if (courierType == 'store')
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Штатный',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Фрилансер',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
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
                  onTap: onRemove,
                  child: const Row(
                    children: [
                      Icon(Icons.person_remove, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Убрать из магазина',
                          style: TextStyle(color: Colors.red)),
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
        return Icons.electric_bike_rounded;
      case 'motorcycle':
      case 'scooter':
        return Icons.two_wheeler_rounded;
      case 'truck':
        return Icons.local_shipping_rounded;
      default:
        return Icons.delivery_dining_rounded;
    }
  }

  String _transportLabel(String type) {
    switch (type) {
      case 'bicycle':
        return '⚡ Электровелосипед';
      case 'motorcycle':
      case 'scooter':
        return '🛵 Муравей';
      case 'truck':
        return '🚚 Грузовой';
      default:
        return type;
    }
  }
}
