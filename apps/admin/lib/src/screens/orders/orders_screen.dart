import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:intl/intl.dart';
import '../../widgets/admin_page_body.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, pending, courier_assigned, picked_up, delivered, cancelled
  final Set<String> _selectedOrderIds = {};

  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);

    try {
      final data = await _supabase
          .from('delivery_orders')
          .select('*, customers(name, phone), couriers(name, phone), warehouses(name)')
          .order('created_at', ascending: false);

      setState(() {
        _orders = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки заказов: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Filtered orders list
  List<Map<String, dynamic>> get _filteredOrders {
    List<Map<String, dynamic>> result = _orders;

    // Apply status filter
    if (_statusFilter != 'all') {
      result = result.where((o) {
        final status = (o['status'] ?? '').toString().toLowerCase();
        if (_statusFilter == 'pending') return status == 'pending';
        if (_statusFilter == 'courier_assigned') return status == 'courier_assigned';
        if (_statusFilter == 'picked_up') return status == 'picked_up';
        if (_statusFilter == 'delivered') return status == 'delivered';
        if (_statusFilter == 'cancelled') return status == 'cancelled';
        return true;
      }).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      result = result.where((o) {
        final number = (o['order_number'] ?? '').toString().toLowerCase();
        final id = (o['id'] ?? '').toString().toLowerCase();
        final custName = (o['customers']?['name'] ?? '').toString().toLowerCase();
        final custPhone = (o['customers']?['phone'] ?? '').toString().toLowerCase();
        final courName = (o['couriers']?['name'] ?? '').toString().toLowerCase();
        return number.contains(_searchQuery) ||
            id.contains(_searchQuery) ||
            custName.contains(_searchQuery) ||
            custPhone.contains(_searchQuery) ||
            courName.contains(_searchQuery);
      }).toList();
    }

    return result;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 760;

    return AdminPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upper Search Bar
          Row(
            children: [
              Expanded(
                child: AdminSearchField(
                  hint: 'Поиск по номеру заказа, имени клиента/курьера...',
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
              if (!isMobile) ...[
                if (_selectedOrderIds.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _confirmDeleteOrders(_selectedOrderIds.toList()),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: Text('Удалить (${_selectedOrderIds.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                const SizedBox(width: 16),
                IconButton(
                  tooltip: 'Обновить заказы',
                  onPressed: _loadOrders,
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.darkTextSecondary),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.darkSurface,
                    padding: const EdgeInsets.all(14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.darkBorder),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (isMobile && _selectedOrderIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _confirmDeleteOrders(_selectedOrderIds.toList()),
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                label: Text('Удалить выбранные (${_selectedOrderIds.length})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Horizontal scrolling Status chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip('Все заказы', 'all'),
                _buildStatusChip('В обработке (Pending)', 'pending'),
                _buildStatusChip('Курьер в пути (Assigned)', 'courier_assigned'),
                _buildStatusChip('Забран курьером (Picked Up)', 'picked_up'),
                _buildStatusChip('Доставлено (Delivered)', 'delivered'),
                _buildStatusChip('Отменено (Cancelled)', 'cancelled'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Orders List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filteredOrders.isEmpty
                    ? const AdminEmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: 'Заказы не найдены',
                        subtitle: 'Нет заказов в этой категории или по вашему запросу',
                      )
                    : isMobile
                        ? ListView.separated(
                            itemCount: _filteredOrders.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) => _buildMobileCard(_filteredOrders[idx]),
                          )
                        : _buildDesktopTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() => _statusFilter = value);
          }
        },
        backgroundColor: AppColors.darkSurface,
        selectedColor: AppColors.primary.withValues(alpha: 0.25),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primaryLight : AppColors.darkTextSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 13,
        ),
        checkmarkColor: AppColors.primaryLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.5) : AppColors.darkBorder),
        ),
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.darkSurfaceVariant),
            dataRowColor: WidgetStateProperty.all(Colors.transparent),
            horizontalMargin: 20,
            columnSpacing: 28,
            showCheckboxColumn: true,
            columns: const [
              DataColumn(label: Text('Номер / ID', style: TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600, fontSize: 13))),
              DataColumn(label: Text('Клиент', style: TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600, fontSize: 13))),
              DataColumn(label: Text('Курьер', style: TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600, fontSize: 13))),
              DataColumn(label: Text('Склад', style: TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600, fontSize: 13))),
              DataColumn(label: Text('Сумма', style: TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600, fontSize: 13))),
              DataColumn(label: Text('Статус', style: TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600, fontSize: 13))),
              DataColumn(label: Text('Создан', style: TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600, fontSize: 13))),
              DataColumn(label: Text('Действия', style: TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600, fontSize: 13))),
            ],
            rows: _filteredOrders.map((o) {
              final id = o['id'] as String;
              final number = o['order_number'] ?? '—';
              final customer = o['customers']?['name'] ?? 'Без имени';
              final courier = o['couriers']?['name'] ?? 'Не назначен';
              final warehouse = o['warehouses']?['name'] ?? '—';
              final total = '${o['total'] ?? 0} с';
              final status = o['status'] ?? '—';
              final isSelected = _selectedOrderIds.contains(id);

              return DataRow(
                selected: isSelected,
                onSelectChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedOrderIds.add(id);
                    } else {
                      _selectedOrderIds.remove(id);
                    }
                  });
                },
                cells: [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        Text(
                          id.substring(0, 8),
                          style: const TextStyle(fontFamily: 'monospace', color: AppColors.darkTextTertiary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(customer, style: const TextStyle(color: Colors.white))),
                  DataCell(Text(courier, style: TextStyle(color: courier == 'Не назначен' ? AppColors.darkTextTertiary : Colors.white))),
                  DataCell(Text(warehouse, style: const TextStyle(color: Colors.white))),
                  DataCell(Text(total, style: const TextStyle(color: AppColors.successLight, fontWeight: FontWeight.bold))),
                  DataCell(_buildStatusBadge(status)),
                  DataCell(Text(_formatDate(o['created_at']), style: const TextStyle(color: AppColors.darkTextSecondary))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 20),
                          onPressed: () => _showOrderDetail(o),
                          tooltip: 'Подробнее',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_forever_rounded, color: AppColors.errorLight, size: 20),
                          onPressed: () => _confirmDeleteOrders([id]),
                          tooltip: 'Удалить заказ',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // MOBILE CARDS
  // ═══════════════════════════════════════════════════════════

  Widget _buildMobileCard(Map<String, dynamic> o) {
    final id = o['id'] as String;
    final number = o['order_number'] ?? '—';
    final customer = o['customers']?['name'] ?? 'Без имени';
    final total = '${o['total'] ?? 0} с';
    final status = o['status'] ?? '—';
    final isSelected = _selectedOrderIds.contains(id);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isSelected ? AppColors.primary : AppColors.darkBorder, width: isSelected ? 1.5 : 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedOrderIds.add(id);
                        } else {
                          _selectedOrderIds.remove(id);
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  Text('Заказ $number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 6),
          Text('Клиент: $customer', style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Создан: ${_formatDate(o['created_at'])}', style: const TextStyle(color: AppColors.darkTextTertiary, fontSize: 11)),
              Text(total, style: const TextStyle(color: AppColors.successLight, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.darkBorder, height: 1),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.info_outline_rounded, size: 16),
                label: const Text('Подробнее', style: TextStyle(fontSize: 12)),
                onPressed: () => _showOrderDetail(o),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_forever_rounded, color: AppColors.errorLight, size: 18),
                onPressed: () => _confirmDeleteOrders([id]),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor = Colors.grey;
    Color textColor = Colors.white;
    String label = status;

    switch (status.toLowerCase()) {
      case 'pending':
        badgeColor = AppColors.warning;
        textColor = AppColors.warningLight;
        label = 'В очереди';
        break;
      case 'courier_assigned':
        badgeColor = AppColors.info;
        textColor = AppColors.infoLight;
        label = 'Курьер назначен';
        break;
      case 'picked_up':
        badgeColor = AppColors.primary;
        textColor = AppColors.primaryLight;
        label = 'В пути';
        break;
      case 'delivered':
        badgeColor = AppColors.success;
        textColor = AppColors.successLight;
        label = 'Доставлен';
        break;
      case 'cancelled':
        badgeColor = AppColors.error;
        textColor = AppColors.errorLight;
        label = 'Отменен';
        break;
      case 'payment_sent':
        badgeColor = AppColors.secondary;
        textColor = AppColors.secondaryLight;
        label = 'Оплата отправлена';
        break;
      case 'payment_verified':
        badgeColor = AppColors.success;
        textColor = AppColors.successLight;
        label = 'Оплата проверена';
        break;
      case 'assembling':
        badgeColor = Colors.purple;
        textColor = Colors.purpleAccent;
        label = 'Сборка';
        break;
      case 'ready':
        badgeColor = Colors.orange;
        textColor = Colors.orangeAccent;
        label = 'Готов к выдаче';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ORDER DETAILS VIEW
  // ═══════════════════════════════════════════════════════════

  Future<void> _showOrderDetail(Map<String, dynamic> o) async {
    // Dynamic fetch of order items
    List<Map<String, dynamic>> items = [];
    bool itemsLoading = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (itemsLoading) {
            _supabase
                .from('delivery_order_items')
                .select('*')
                .eq('order_id', o['id'])
                .then((data) {
                  if (context.mounted) {
                    setDialogState(() {
                      items = List<Map<String, dynamic>>.from(data);
                      itemsLoading = false;
                    });
                  }
                })
                .catchError((_) {
                  if (context.mounted) {
                    setDialogState(() {
                      itemsLoading = false;
                    });
                  }
                });
          }

          final customer = o['customers']?['name'] ?? '—';
          final phone = o['customers']?['phone'] ?? '—';
          final courier = o['couriers']?['name'] ?? 'Не назначен';
          final warehouse = o['warehouses']?['name'] ?? '—';
          
          return AlertDialog(
            backgroundColor: AppColors.darkSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.darkBorder)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Заказ ${o['order_number'] ?? ''}', style: const TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.bold)),
                _buildStatusBadge(o['status'] ?? ''),
              ],
            ),
            content: SizedBox(
              width: 650,
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Customer info card
                      _buildDialogSectionHeader('👤 Данные клиента'),
                      Text('Имя: $customer', style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('Телефон: $phone', style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('Адрес доставки: ${o['delivery_address'] ?? '—'}', style: const TextStyle(color: Colors.white)),
                      
                      const SizedBox(height: 16),
                      // Courier & Warehouse
                      _buildDialogSectionHeader('🚚 Логистика'),
                      Text('Курьер: $courier', style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('Склад отправки: $warehouse', style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('Тип доставки: ${o['requested_transport'] ?? 'Любой'}', style: const TextStyle(color: Colors.white)),

                      const SizedBox(height: 16),
                      // Items list table
                      _buildDialogSectionHeader('📦 Позиции в заказе'),
                      itemsLoading
                          ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                          : items.isEmpty
                              ? const Text('Позиции не найдены', style: TextStyle(color: AppColors.darkTextTertiary))
                              : Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(4),
                                    1: FlexColumnWidth(1.5),
                                    2: FlexColumnWidth(1.5),
                                    3: FlexColumnWidth(1.8),
                                  },
                                  children: [
                                    TableRow(
                                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.darkBorder))),
                                      children: [
                                        _tableHeaderCell('Товар'),
                                        _tableHeaderCell('Цена'),
                                        _tableHeaderCell('Кол-во'),
                                        _tableHeaderCell('Сумма'),
                                      ],
                                    ),
                                    ...items.map((it) => TableRow(
                                      children: [
                                        _tableBodyCell(it['name'] ?? '—'),
                                        _tableBodyCell('${it['unit_price'] ?? 0} с'),
                                        _tableBodyCell('x${it['quantity'] ?? 1}'),
                                        _tableBodyCell('${it['total'] ?? 0} с', isBold: true),
                                      ],
                                    )),
                                  ],
                                ),

                      const SizedBox(height: 20),
                      // Financial breakdown card
                      _buildDialogSectionHeader('💵 Детализация оплаты'),
                      _buildFinRow('Стоимость товаров', '${o['items_total'] ?? 0} с'),
                      _buildFinRow('Стоимость доставки', '${o['delivery_fee'] ?? 0} с'),
                      if (o['courier_earning'] != null)
                        _buildFinRow('Доход курьера', '${o['courier_earning']} с', isDim: true),
                      if (o['platform_earning'] != null)
                        _buildFinRow('Комиссия платформы', '${o['platform_earning']} с', isDim: true),
                      const Divider(color: AppColors.darkBorder),
                      _buildFinRow('Итоговая сумма', '${o['total'] ?? 0} с', isBold: true, isAccent: true),
                      
                      const SizedBox(height: 16),
                      // General details
                      _buildDialogSectionHeader('📅 Системные данные'),
                      Text('ID заказа: ${o['id']}', style: const TextStyle(fontFamily: 'monospace', color: AppColors.darkTextSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Создан: ${_formatDate(o['created_at'])}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                      if (o['delivered_at'] != null) ...[
                        const SizedBox(height: 4),
                        Text('Доставлен: ${_formatDate(o['delivered_at'])}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Закрыть', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialogSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _tableHeaderCell(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(label, style: const TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _tableBodyCell(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildFinRow(String label, String value, {bool isBold = false, bool isAccent = false, bool isDim = false}) {
    Color valueColor = Colors.white;
    if (isAccent) valueColor = AppColors.successLight;
    if (isDim) valueColor = AppColors.darkTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDim ? AppColors.darkTextTertiary : AppColors.darkTextSecondary, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 15 : 13,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DELETE ORDER CASCADING
  // ═══════════════════════════════════════════════════════════

  Future<void> _confirmDeleteOrders(List<String> ids) async {
    if (ids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.darkBorder)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.errorLight),
            const SizedBox(width: 10),
            Text(ids.length == 1 ? 'Удаление заказа' : 'Удаление заказов', style: const TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ids.length == 1 
                ? 'Вы действительно хотите удалить выбранный заказ?' 
                : 'Вы действительно хотите удалить ${ids.length} выбранных заказов?', 
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            Text(
              'Это действие удалит позиции заказа, историю статусов, транзакции, отзывы и переписку в чате.',
              style: TextStyle(color: AppColors.errorLight.withValues(alpha: 0.85), fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text('Данное действие НЕОБРАТИМО.', style: TextStyle(color: AppColors.errorLight, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: AppColors.darkTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          color: AppColors.darkSurface,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.error),
                SizedBox(width: 20),
                Text('Удаление заказов...', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      int successCount = 0;
      for (final orderId in ids) {
        // Cascade deletions for delivery order
        try { await _supabase.from('delivery_order_items').delete().eq('order_id', orderId); } catch (_) {}
        try { await _supabase.from('delivery_order_messages').delete().eq('order_id', orderId); } catch (_) {}
        try { await _supabase.from('delivery_order_ratings').delete().eq('order_id', orderId); } catch (_) {}
        try { await _supabase.from('delivery_ratings').delete().eq('order_id', orderId); } catch (_) {}
        try { await _supabase.from('delivery_order_status_history').delete().eq('order_id', orderId); } catch (_) {}
        try { await _supabase.from('transactions').delete().eq('order_id', orderId); } catch (_) {}
        
        // Final order deletion
        await _supabase.from('delivery_orders').delete().eq('id', orderId);
        successCount++;
      }

      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading overlay safely
      }

      setState(() {
        _selectedOrderIds.removeAll(ids);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Успешно удалено заказов: $successCount из ${ids.length}'),
            backgroundColor: AppColors.success,
          ),
        );
      }

      _loadOrders();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading overlay safely
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления заказов: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
