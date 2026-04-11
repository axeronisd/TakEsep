import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

/// ═══════════════════════════════════════════════════════════════
/// Couriers Management Screen — Admin Panel
///
/// Управление курьерами Ак Жол:
/// - Список всех курьеров
/// - Добавление курьера с генерацией ключа
/// - Перегенерация ключа
/// - Активация/деактивация
/// - Привязка к складу
/// ═══════════════════════════════════════════════════════════════

class CouriersScreen extends StatefulWidget {
  const CouriersScreen({super.key});

  @override
  State<CouriersScreen> createState() => _CouriersScreenState();
}

class _CouriersScreenState extends State<CouriersScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _couriers = [];
  List<Map<String, dynamic>> _warehouses = [];
  bool _loading = true;
  String _filter = 'all'; // all, active, inactive

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final couriers = await _supabase
          .from('couriers')
          .select('*, courier_warehouse(warehouse_id, is_active, warehouses(name))')
          .order('created_at', ascending: false);
      
      final warehouses = await _supabase
          .from('warehouses')
          .select('id, name, address')
          .order('name');

      setState(() {
        _couriers = List<Map<String, dynamic>>.from(couriers);
        _warehouses = List<Map<String, dynamic>>.from(warehouses);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredCouriers {
    if (_filter == 'active') return _couriers.where((c) => c['is_active'] == true).toList();
    if (_filter == 'inactive') return _couriers.where((c) => c['is_active'] != true).toList();
    return _couriers;
  }

  String _generateAccessKey() {
    final rng = Random.secure();
    return List.generate(6, (_) => rng.nextInt(10)).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delivery_dining, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Курьеры Ак Жол',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    Text('${_couriers.length} курьеров',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                  ],
                ),
                const Spacer(),
                // Filter chips
                _FilterChip(label: 'Все', value: 'all', current: _filter,
                    onTap: () => setState(() => _filter = 'all')),
                const SizedBox(width: 8),
                _FilterChip(label: 'Активные', value: 'active', current: _filter,
                    onTap: () => setState(() => _filter = 'active')),
                const SizedBox(width: 8),
                _FilterChip(label: 'Отключённые', value: 'inactive', current: _filter,
                    onTap: () => setState(() => _filter = 'inactive')),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAddCourierDialog(),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Добавить курьера'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A3E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _HeaderCell('Курьер', flex: 3),
                  _HeaderCell('Телефон', flex: 2),
                  _HeaderCell('Ключ', flex: 2),
                  _HeaderCell('Транспорт', flex: 2),
                  _HeaderCell('Ставка', flex: 1),
                  _HeaderCell('Склады', flex: 2),
                  _HeaderCell('Статус', flex: 1),
                  _HeaderCell('Действия', flex: 2),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredCouriers.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: _filteredCouriers.length,
                          itemBuilder: (_, i) => _buildCourierRow(_filteredCouriers[i]),
                        ),
            ),
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
          Icon(Icons.delivery_dining, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text('Нет курьеров', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
          const SizedBox(height: 8),
          Text('Нажмите "Добавить курьера" чтобы создать первого',
              style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildCourierRow(Map<String, dynamic> courier) {
    final isActive = courier['is_active'] == true;
    final isOnline = courier['is_online'] == true;
    final accessKey = courier['access_key'] ?? '—';
    final linkedWarehouses = (courier['courier_warehouse'] as List? ?? [])
        .where((w) => w['is_active'] == true)
        .toList();
    final warehouseNames = linkedWarehouses
        .map((w) => w['warehouses']?['name'] ?? '?')
        .join(', ');

    return GestureDetector(
      onTap: () => _showCourierDetailDialog(courier),
      child: Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF12122B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? Colors.transparent : Colors.red.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Name + online status
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF2ECC71).withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (courier['name'] as String? ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isActive ? const Color(0xFF2ECC71) : Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(courier['name'] ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Row(
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: isOnline ? Colors.greenAccent : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(isOnline ? 'Онлайн' : 'Офлайн',
                              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Phone
          Expanded(
            flex: 2,
            child: Text(courier['phone'] ?? '—',
                style: TextStyle(fontSize: 13, color: Colors.grey[300])),
          ),

          // Access Key
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(accessKey,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFA29BFE),
                            letterSpacing: 1),
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: accessKey));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ключ скопирован'),
                          duration: Duration(seconds: 1)),
                    );
                  },
                  child: Icon(Icons.copy, size: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          // Transport
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(_transportIcon(courier['transport_type'] ?? ''),
                    size: 16, color: Colors.grey[400]),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(_transportLabel(courier['transport_type'] ?? ''),
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),

          // Earning Rate
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () => _showEditRateDialog(courier),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${((courier['earning_rate'] as num?)?.toDouble() ?? 0.90) * 100 ~/ 1}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2ECC71),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // Warehouses
          Expanded(
            flex: 2,
            child: Text(
              warehouseNames.isEmpty ? '—' : warehouseNames,
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),

          // Status
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isActive ? 'Актив' : 'Откл.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.greenAccent : Colors.red[300],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Actions
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionButton(
                  icon: Icons.percent,
                  tooltip: 'Изменить ставку',
                  color: const Color(0xFF2ECC71),
                  onTap: () => _showEditRateDialog(courier),
                ),
                const SizedBox(width: 4),
                _ActionButton(
                  icon: Icons.refresh,
                  tooltip: 'Новый ключ',
                  color: const Color(0xFF6C5CE7),
                  onTap: () => _regenerateKey(courier),
                ),
                const SizedBox(width: 4),
                _ActionButton(
                  icon: Icons.store,
                  tooltip: 'Привязать склад',
                  color: Colors.blue,
                  onTap: () => _showLinkWarehouseDialog(courier),
                ),
                const SizedBox(width: 4),
                _ActionButton(
                  icon: isActive ? Icons.block : Icons.check_circle,
                  tooltip: isActive ? 'Отключить' : 'Активировать',
                  color: isActive ? Colors.orange : Colors.green,
                  onTap: () => _toggleActive(courier),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════

  void _showAddCourierDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String transport = 'bicycle';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A3E),
          title: const Text('Добавить курьера'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Имя курьера',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: InputDecoration(
                    labelText: 'Номер телефона',
                    prefixIcon: const Icon(Icons.phone),
                    prefixText: '+996 ',
                    prefixStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    hintText: '700123456',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                const Text('Транспорт:', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Электровелосипед'),
                      selected: transport == 'bicycle',
                      onSelected: (_) => setDialogState(() => transport = 'bicycle'),
                    ),
                    ChoiceChip(
                      label: const Text('Муравей'),
                      selected: transport == 'scooter',
                      onSelected: (_) => setDialogState(() => transport = 'scooter'),
                    ),
                  ],
                ),

              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Заполните все поля'), backgroundColor: Colors.orange),
                  );
                  return;
                }
                Navigator.pop(ctx);
                await _createCourier(
                  name: nameCtrl.text.trim(),
                  phone: '+996${phoneCtrl.text.trim()}',
                  transport: transport,
                );
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Создать'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC71)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkWarehouseDialog(Map<String, dynamic> courier) {
    final linkedIds = ((courier['courier_warehouse'] as List?) ?? [])
        .where((w) => w['is_active'] == true)
        .map<String>((w) => w['warehouse_id'] as String)
        .toSet();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A3E),
          title: Text('Склады для ${courier['name']}'),
          content: SizedBox(
            width: 400,
            height: 300,
            child: _warehouses.isEmpty
                ? const Center(child: Text('Нет складов'))
                : ListView.builder(
                    itemCount: _warehouses.length,
                    itemBuilder: (_, i) {
                      final wh = _warehouses[i];
                      final isLinked = linkedIds.contains(wh['id']);
                      return CheckboxListTile(
                        title: Text(wh['name'] ?? '—'),
                        subtitle: Text(wh['address'] ?? '', style: const TextStyle(fontSize: 12)),
                        value: isLinked,
                        activeColor: const Color(0xFF2ECC71),
                        onChanged: (val) async {
                          if (val == true) {
                            await _linkWarehouse(courier['id'], wh['id']);
                            linkedIds.add(wh['id']);
                          } else {
                            await _unlinkWarehouse(courier['id'], wh['id']);
                            linkedIds.remove(wh['id']);
                          }
                          setDialogState(() {});
                        },
                      );
                    },
                  ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }

  void _showKeyDialog(String name, String key) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        icon: const Icon(Icons.vpn_key, color: Color(0xFF2ECC71), size: 48),
        title: Text('Ключ для $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Передайте этот ключ курьеру для входа в приложение',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.3)),
              ),
              child: Text(
                key,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFA29BFE),
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: key));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ключ скопирован'), duration: Duration(seconds: 1)),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Скопировать'),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }

  void _showEditRateDialog(Map<String, dynamic> courier) {
    double rate = ((courier['earning_rate'] as num?)?.toDouble() ?? 0.90);
    final name = courier['name'] ?? 'Курьер';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A3E),
          title: Text('Ставка: $name'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Процент от стоимости доставки, который получает курьер',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 24),
                Text(
                  '${(rate * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2ECC71),
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: rate,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  activeColor: const Color(0xFF2ECC71),
                  label: '${(rate * 100).toStringAsFixed(0)}%',
                  onChanged: (v) => setDialogState(() => rate = v),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [50, 70, 80, 90, 100].map((p) {
                    final isSelected = (rate * 100).round() == p;
                    return GestureDetector(
                      onTap: () => setDialogState(() => rate = p / 100),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2ECC71).withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2ECC71)
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text('$p%',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSelected ? const Color(0xFF2ECC71) : Colors.grey,
                            )),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'При доставке 100 сом курьер получит ${(100 * rate).toStringAsFixed(0)} сом',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _supabase.from('couriers').update({
                    'earning_rate': rate,
                  }).eq('id', courier['id']);
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Ставка $name обновлена: ${(rate * 100).toStringAsFixed(0)}%'),
                        backgroundColor: const Color(0xFF2ECC71),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Сохранить'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC71)),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════

  Future<void> _createCourier({
    required String name,
    required String phone,
    required String transport,
  }) async {
    final key = _generateAccessKey();
    try {
      await _supabase.from('couriers').insert({
        'name': name,
        'phone': phone,
        'access_key': key,
        'transport_type': transport,
        'courier_type': 'store',
        'is_active': true,
        'is_online': false,
      });

      _showKeyDialog(name, key);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _regenerateKey(Map<String, dynamic> courier) async {
    final key = _generateAccessKey();
    try {
      await _supabase.from('couriers').update({
        'access_key': key,
      }).eq('id', courier['id']);

      _showKeyDialog(courier['name'], key);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> courier) async {
    final isActive = courier['is_active'] == true;
    try {
      await _supabase.from('couriers').update({
        'is_active': !isActive,
      }).eq('id', courier['id']);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _linkWarehouse(String courierId, String warehouseId) async {
    try {
      await _supabase.from('courier_warehouse').upsert({
        'courier_id': courierId,
        'warehouse_id': warehouseId,
        'is_active': true,
      });

      // Обновить тип курьера на 'store'
      await _supabase.from('couriers').update({
        'courier_type': 'store',
      }).eq('id', courierId);
    } catch (e) {
      debugPrint('Link error: $e');
    }
  }

  Future<void> _unlinkWarehouse(String courierId, String warehouseId) async {
    try {
      await _supabase.from('courier_warehouse').update({
        'is_active': false,
        'left_at': DateTime.now().toIso8601String(),
      }).eq('courier_id', courierId).eq('warehouse_id', warehouseId);

      // Проверить есть ли ещё активные связи
      final remaining = await _supabase
          .from('courier_warehouse')
          .select('id')
          .eq('courier_id', courierId)
          .eq('is_active', true);

      if ((remaining as List).isEmpty) {
        await _supabase.from('couriers').update({
          'courier_type': 'freelance',
        }).eq('id', courierId);
      }
    } catch (e) {
      debugPrint('Unlink error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // COURIER DETAIL DIALOG — Rating, Reviews, Debt, Payments
  // ═══════════════════════════════════════════════════════════

  void _showCourierDetailDialog(Map<String, dynamic> courier) async {
    final courierId = courier['id'] as String;
    final name = courier['name'] ?? 'Курьер';
    final earningRate = (courier['earning_rate'] as num?)?.toDouble() ?? 0.90;

    // Load data in parallel
    List<Map<String, dynamic>> reviews = [];
    double totalCollected = 0; // Total delivery_fee collected by courier
    double totalDebt = 0;      // Amount courier owes to AkJol
    double totalPaid = 0;
    double avgRating = 0;
    int totalOrders = 0;

    try {
      // Load delivered orders with ratings
      final orders = await _supabase
          .from('delivery_orders')
          .select('id, items_total, delivery_fee, courier_earning, courier_rating, courier_review, order_number, delivered_at, customer_id, customers(name)')
          .eq('courier_id', courierId)
          .eq('status', 'delivered')
          .order('delivered_at', ascending: false);

      totalOrders = orders.length;

      double ratingSum = 0;
      int ratingCount = 0;

      for (final o in orders) {
        final deliveryFee = (o['delivery_fee'] as num?)?.toDouble() ?? 0;
        final courierEarning = (o['courier_earning'] as num?)?.toDouble() 
            ?? (deliveryFee * earningRate);
        
        totalCollected += deliveryFee;
        // Courier owes the difference: delivery_fee - courier_earning
        totalDebt += (deliveryFee - courierEarning);

        final rating = (o['courier_rating'] as num?)?.toDouble();
        if (rating != null && rating > 0) {
          ratingSum += rating;
          ratingCount++;
          if (o['courier_review'] != null && (o['courier_review'] as String).isNotEmpty) {
            reviews.add(o);
          }
        }
      }

      avgRating = ratingCount > 0 ? ratingSum / ratingCount : 0;

      // Load payments
      try {
        final payments = await _supabase
            .from('courier_payments')
            .select('*')
            .eq('courier_id', courierId)
            .order('created_at', ascending: false);
        for (final p in payments) {
          totalPaid += (p['amount'] as num?)?.toDouble() ?? 0;
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error loading courier detail: $e');
    }

    final remainingDebt = totalDebt - totalPaid;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        title: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: Color(0xFF2ECC71),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 18)),
                  Text(
                    '$totalOrders доставок',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          height: 500,
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                TabBar(
                  indicatorColor: const Color(0xFF2ECC71),
                  labelColor: const Color(0xFF2ECC71),
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: 'Рейтинг'),
                    Tab(text: 'Финансы'),
                    Tab(text: 'Отзывы'),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    children: [
                      // ── Tab 1: Rating ──
                      Column(
                        children: [
                          const SizedBox(height: 20),
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2ECC71),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (i) {
                              final starValue = i + 1;
                              return Icon(
                                starValue <= avgRating.round()
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: Colors.amber,
                                size: 32,
                              );
                            }),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${reviews.length} отзывов из $totalOrders заказов',
                            style: TextStyle(color: Colors.grey[400], fontSize: 13),
                          ),
                        ],
                      ),

                      // ── Tab 2: Finances/Debt ──
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            // Debt summary
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: remainingDebt > 0
                                    ? Colors.red.withValues(alpha: 0.08)
                                    : Colors.green.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: remainingDebt > 0
                                      ? Colors.red.withValues(alpha: 0.3)
                                      : Colors.green.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Total delivery fees collected
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Собрано за доставку:',
                                          style: TextStyle(fontSize: 13)),
                                      Text('${totalCollected.toStringAsFixed(0)} сом',
                                          style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Courier's share
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Доля курьера (${(earningRate * 100).toStringAsFixed(0)}%):',
                                          style: const TextStyle(fontSize: 13)),
                                      Text('−${(totalCollected * earningRate).toStringAsFixed(0)} сом',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2ECC71),
                                          )),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // What courier owes AkJol
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Доля AkJol (${((1 - earningRate) * 100).toStringAsFixed(0)}%):',
                                          style: const TextStyle(fontSize: 13)),
                                      Text('${totalDebt.toStringAsFixed(0)} сом',
                                          style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Confirmed payments
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Оплачено:',
                                          style: TextStyle(fontSize: 13)),
                                      Text('−${totalPaid.toStringAsFixed(0)} сом',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2ECC71),
                                          )),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        remainingDebt > 0 ? 'Долг:' : 'Баланс:',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '${remainingDebt.toStringAsFixed(0)} сом',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: remainingDebt > 0 ? Colors.red : const Color(0xFF2ECC71),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Payment confirmation button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showConfirmPaymentDialog(courier, remainingDebt);
                                },
                                icon: const Icon(Icons.payments_rounded, size: 18),
                                label: const Text('Подтвердить оплату'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2ECC71),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Tab 3: Reviews ──
                      reviews.isEmpty
                          ? Center(
                              child: Text('Нет отзывов',
                                  style: TextStyle(color: Colors.grey[500])),
                            )
                          : ListView.builder(
                              itemCount: reviews.length,
                              itemBuilder: (_, i) {
                                final r = reviews[i];
                                final rating = (r['courier_rating'] as num?)?.toInt() ?? 0;
                                final review = r['courier_review'] ?? '';
                                final customerName = r['customers']?['name'] ?? 'Клиент';
                                final orderNum = r['order_number'] ?? '';
                                final deliveredAt = r['delivered_at'] ?? '';
                                String dateLabel = '';
                                final dt = DateTime.tryParse(deliveredAt.toString());
                                if (dt != null) {
                                  dateLabel = '${dt.day}.${dt.month}.${dt.year}';
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          ...List.generate(5, (s) => Icon(
                                            s < rating ? Icons.star_rounded : Icons.star_border_rounded,
                                            color: Colors.amber,
                                            size: 16,
                                          )),
                                          const Spacer(),
                                          Text(dateLabel,
                                              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(review,
                                          style: const TextStyle(fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Text('$customerName • $orderNum',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _showConfirmPaymentDialog(Map<String, dynamic> courier, double currentDebt) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        title: Text('Оплата от ${courier['name']}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Текущий долг:'),
                    Text(
                      '${currentDebt.toStringAsFixed(0)} сом',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Сумма оплаты (сом)',
                  prefixIcon: Icon(Icons.payments_rounded),
                  suffixText: 'сом',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Комментарий (необязательно)',
                  prefixIcon: Icon(Icons.note),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim());
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Введите корректную сумму'), backgroundColor: Colors.orange),
                );
                return;
              }

              Navigator.pop(ctx);
              try {
                await _supabase.from('courier_payments').insert({
                  'courier_id': courier['id'],
                  'amount': amount,
                  'note': noteCtrl.text.trim(),
                  'confirmed_by': 'admin',
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Оплата ${amount.toStringAsFixed(0)} сом от ${courier['name']} подтверждена'),
                      backgroundColor: const Color(0xFF2ECC71),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Подтвердить'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC71)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════

  IconData _transportIcon(String type) {
    switch (type) {
      case 'bicycle': return Icons.electric_bike_rounded;
      case 'scooter': return Icons.electric_rickshaw_rounded;
      case 'motorcycle': return Icons.two_wheeler_rounded;
      case 'truck': return Icons.local_shipping_rounded;
      default: return Icons.delivery_dining_rounded;
    }
  }

  String _transportLabel(String type) {
    switch (type) {
      case 'bicycle': return 'Электровело';
      case 'scooter': return 'Муравей';
      case 'motorcycle': return 'Мотоцикл';
      case 'truck': return 'Грузовой';
      default: return type;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  const _HeaderCell(this.label, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
              letterSpacing: 0.5)),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label, required this.value,
    required this.current, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C5CE7).withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF6C5CE7) : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? const Color(0xFFA29BFE) : Colors.grey[500],
            )),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon, required this.tooltip,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
