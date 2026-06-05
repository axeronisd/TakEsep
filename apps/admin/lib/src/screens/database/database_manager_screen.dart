import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

/// Full database access screen for the admin panel.
/// Displays all Supabase tables in a structured, browsable UI
/// with the ability to view, search, and delete records.
class DatabaseManagerScreen extends StatefulWidget {
  const DatabaseManagerScreen({super.key});

  @override
  State<DatabaseManagerScreen> createState() => _DatabaseManagerScreenState();
}

class _DatabaseManagerScreenState extends State<DatabaseManagerScreen> {
  final _supabase = Supabase.instance.client;

  // ── Table definitions ──
  static const _tableGroups = <_TableGroup>[
    _TableGroup('Пользователи', Icons.people, [
      _TableDef('auth_users', 'Аккаунты (auth.users)', Icons.person, isAuth: true),
      _TableDef('customers', 'Клиенты', Icons.person_outline),
      _TableDef('couriers', 'Курьеры', Icons.delivery_dining),
      _TableDef('employees', 'Сотрудники', Icons.badge),
    ]),
    _TableGroup('Компании и Склады', Icons.business, [
      _TableDef('companies', 'Компании', Icons.business),
      _TableDef('warehouses', 'Склады', Icons.warehouse),
      _TableDef('warehouse_settings', 'Настройки складов', Icons.settings),
    ]),
    _TableGroup('Товары и Каталог', Icons.inventory_2, [
      _TableDef('categories', 'Категории', Icons.category),
      _TableDef('products', 'Товары', Icons.shopping_bag),
      _TableDef('product_prices', 'Цены товаров', Icons.attach_money),
      _TableDef('modifier_groups', 'Группы модификаторов', Icons.tune),
      _TableDef('modifier_options', 'Опции модификаторов', Icons.list),
      _TableDef('product_modifiers', 'Связи товар↔модификатор', Icons.link),
    ]),
    _TableGroup('Заказы и Доставка', Icons.local_shipping, [
      _TableDef('delivery_orders', 'Заказы на доставку', Icons.receipt_long),
      _TableDef('delivery_order_items', 'Позиции заказов', Icons.list_alt),
      _TableDef('delivery_order_messages', 'Чат заказов', Icons.chat),
      _TableDef('delivery_order_ratings', 'Рейтинги', Icons.star),
      _TableDef('courier_locations', 'Геолокация курьеров', Icons.location_on),
      _TableDef('courier_earnings', 'Заработок курьеров', Icons.monetization_on),
    ]),
    _TableGroup('Продажи', Icons.point_of_sale, [
      _TableDef('sales', 'Продажи', Icons.shopping_cart),
      _TableDef('sale_items', 'Позиции продаж', Icons.list),
      _TableDef('payment_methods', 'Способы оплаты', Icons.payment),
    ]),
    _TableGroup('Склад (операции)', Icons.inventory, [
      _TableDef('arrivals', 'Поступления', Icons.move_to_inbox),
      _TableDef('arrival_items', 'Позиции поступлений', Icons.list),
      _TableDef('write_offs', 'Списания', Icons.delete_sweep),
      _TableDef('write_off_items', 'Позиции списаний', Icons.list),
      _TableDef('transfers', 'Перемещения', Icons.swap_horiz),
      _TableDef('transfer_items', 'Позиции перемещений', Icons.list),
      _TableDef('audits', 'Инвентаризации', Icons.fact_check),
      _TableDef('audit_items', 'Позиции инвентаризаций', Icons.list),
    ]),
    _TableGroup('Услуги', Icons.build, [
      _TableDef('services', 'Услуги', Icons.build_circle),
      _TableDef('service_requests', 'Заявки на услуги', Icons.assignment),
    ]),
    _TableGroup('Хранилище', Icons.cloud, [
      _TableDef('storage_objects', 'Файлы (storage)', Icons.folder, isStorage: true),
    ]),
  ];

  String? _selectedTable;
  String? _selectedTableLabel;
  bool _isAuth = false;
  bool _isStorage = false;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false;
  String? _error;
  Set<String> _selectedIds = {};
  bool _selectAll = false;
  String _searchQuery = '';
  String _wipingStatus = '';
  bool _wiping = false;

  int _totalCount = 0;
  int _page = 0;
  static const _pageSize = 50;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 720;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.darkBackground,
          // Mobile: use AppBar + Drawer for table navigation
          appBar: isMobile
              ? AppBar(
                  backgroundColor: AppColors.darkSurface,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  title: Text(_selectedTableLabel ?? 'База данных',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.darkTextPrimary)),
                  iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
                  leading: Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  actions: [
                    if (_selectedTable != null)
                      IconButton(
                        onPressed: _fetchPage,
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Обновить',
                      ),
                  ],
                )
              : null,
          drawer: isMobile ? _buildSidebarDrawer(cs) : null,
          body: isMobile
              ? (_selectedTable == null ? _buildEmptyState() : _buildDataView())
              : Row(
                  children: [
                    // ── Table list sidebar ──
                    Container(
                      width: 280,
                      decoration: const BoxDecoration(
                        color: AppColors.darkSurface,
                        border: Border(right: BorderSide(color: AppColors.darkBorder)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.storage, color: AppColors.primary, size: 22),
                                SizedBox(width: 10),
                                Text('База данных',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.darkTextPrimary,
                                    )),
                              ],
                            ),
                          ),
                          const Divider(color: AppColors.darkBorder, height: 1),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              children: _tableGroups.map((group) {
                                return _buildTableGroup(group);
                              }).toList(),
                            ),
                          ),
                          const Divider(color: AppColors.darkBorder, height: 1),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _confirmWipeAll,
                                icon: const Icon(Icons.delete_forever, size: 18),
                                label: const Text('Очистить ВСЁ'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.errorLight,
                                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _selectedTable == null
                          ? _buildEmptyState()
                          : _buildDataView(),
                    ),
                  ],
                ),
        ),

        // ── Wiping overlay ──
        if (_wiping)
          Container(
            color: Colors.black.withValues(alpha: 0.7),
            child: Center(
              child: Card(
                color: AppColors.darkSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.darkBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                      const SizedBox(height: 20),
                      const Text('Очистка базы...',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary)),
                      const SizedBox(height: 8),
                      Text(_wipingStatus,
                          style: const TextStyle(fontSize: 13, color: AppColors.darkTextSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSidebarDrawer(ColorScheme cs) {
    return Drawer(
      backgroundColor: AppColors.darkSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.storage, color: AppColors.primary, size: 22),
                SizedBox(width: 10),
                Text('База данных',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.darkTextPrimary)),
              ],
            ),
          ),
          const Divider(color: AppColors.darkBorder, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _tableGroups.map((group) => _buildTableGroup(group, closeDrawer: true)).toList(),
            ),
          ),
          const Divider(color: AppColors.darkBorder, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _confirmWipeAll,
                icon: const Icon(Icons.delete_forever, size: 18),
                label: const Text('Очистить ВСЁ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.errorLight,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TABLE GROUP SIDEBAR
  // ═══════════════════════════════════════════════════════════

  Widget _buildTableGroup(_TableGroup group, {bool closeDrawer = false}) {
    return ExpansionTile(
      leading: Icon(group.icon, size: 18, color: AppColors.darkTextTertiary),
      title: Text(group.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.darkTextSecondary,
            letterSpacing: 0.5,
          )),
      dense: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: EdgeInsets.zero,
      initiallyExpanded: true,
      iconColor: AppColors.darkTextTertiary,
      collapsedIconColor: AppColors.darkTextTertiary,
      children: group.tables.map((table) {
        final isActive = _selectedTable == table.key;
        return InkWell(
          onTap: () {
            _loadTable(table);
            if (closeDrawer && mounted) Navigator.of(context).pop();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(table.icon,
                    size: 16,
                    color: isActive ? AppColors.primaryLight : AppColors.darkTextTertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(table.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: isActive ? AppColors.darkTextPrimary : AppColors.darkTextSecondary,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      )),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // LOAD TABLE
  // ═══════════════════════════════════════════════════════════

  Future<void> _loadTable(_TableDef table) async {
    setState(() {
      _selectedTable = table.key;
      _selectedTableLabel = table.label;
      _isAuth = table.isAuth;
      _isStorage = table.isStorage;
      _loading = true;
      _error = null;
      _rows = [];
      _selectedIds = {};
      _selectAll = false;
      _page = 0;
      _searchQuery = '';
    });

    await _fetchPage();
  }

  Future<void> _fetchPage() async {
    setState(() => _loading = true);

    try {
      if (_isAuth) {
        // Auth users — use admin API (service_role key)
        final users = await _supabase.auth.admin.listUsers(
          page: _page + 1,
          perPage: _pageSize,
        );
        _totalCount = users.length; // approximate

        setState(() {
          _rows = users.map((u) => <String, dynamic>{
            'id': u.id,
            'email': u.email ?? '',
            'phone': u.phone ?? '',
            'created_at': u.createdAt,
            'last_sign_in': u.lastSignInAt ?? '',
            'role': u.role ?? '',
          }).toList();
          _loading = false;
        });
      } else if (_isStorage) {
        // List files from known buckets
        final allFiles = <Map<String, dynamic>>[];
        for (final bucket in ['order-receipts', 'avatars', 'product-images']) {
          try {
            final files = await _supabase.storage.from(bucket).list();
            for (final f in files) {
              allFiles.add({
                'id': f.id ?? '${bucket}/${f.name}',
                'bucket': bucket,
                'name': f.name,
                'created_at': f.createdAt,
                'updated_at': f.updatedAt,
              });
            }
          } catch (_) {}
        }
        
        setState(() {
          _rows = allFiles;
          _totalCount = allFiles.length;
          _loading = false;
        });
      } else {
        // Try to get count
        try {
          final countResp = await _supabase
              .from(_selectedTable!)
              .select('id')
              .count(CountOption.exact);
          _totalCount = countResp.count;
        } catch (_) {
          _totalCount = 0;
        }

        // Fetch data — try with created_at order, fallback without
        List<dynamic> data;
        try {
          data = await _supabase
              .from(_selectedTable!)
              .select()
              .range(_page * _pageSize, (_page + 1) * _pageSize - 1)
              .order('created_at', ascending: false);
        } catch (_) {
          // Table may not have created_at — fetch without ordering
          try {
            data = await _supabase
                .from(_selectedTable!)
                .select()
                .range(_page * _pageSize, (_page + 1) * _pageSize - 1);
          } catch (e2) {
            // Table might not exist at all
            setState(() {
              _error = e2.toString();
              _loading = false;
            });
            return;
          }
        }

        if (_totalCount == 0 && data.isNotEmpty) {
          _totalCount = data.length;
        }

        setState(() {
          _rows = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // DATA VIEW
  // ═══════════════════════════════════════════════════════════

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storage, size: 64, color: AppColors.darkTextTertiary),
          const SizedBox(height: 16),
          Text('Выберите таблицу слева',
              style: TextStyle(fontSize: 16, color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Вы сможете просматривать и удалять записи',
              style: TextStyle(fontSize: 13, color: AppColors.darkTextTertiary)),
        ],
      ),
    );
  }

  Widget _buildDataView() {
    final isMobile = MediaQuery.of(context).size.width < 720;
    
    final filtered = _searchQuery.isEmpty
        ? _rows
        : _rows.where((row) {
            return row.values.any((v) =>
                v.toString().toLowerCase().contains(_searchQuery));
          }).toList();

    return Column(
      children: [
        // ── Toolbar ──
        _buildToolbar(),

        // ── Content ──
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)))
              : _error != null
                  ? _buildErrorView()
                  : _rows.isEmpty
                      ? _buildEmptyTable()
                      : (filtered.isEmpty && _searchQuery.isNotEmpty)
                          ? Center(
                              child: Text('Ничего не найдено по запросу "$_searchQuery"',
                                  style: const TextStyle(color: AppColors.darkTextTertiary)),
                            )
                          : isMobile
                              ? _buildMobileDataList(filtered)
                              : _buildDataTable(filtered),
        ),

        // ── Pagination ──
        if (!_loading && _rows.isNotEmpty) _buildPagination(),
      ],
    );
  }

  Widget _buildToolbar() {
    final isMobile = MediaQuery.of(context).size.width < 720;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_totalCount записей',
                    style: const TextStyle(fontSize: 12, color: AppColors.darkTextTertiary)),
                const SizedBox(height: 8),
                // Search
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  style: const TextStyle(fontSize: 13, color: AppColors.darkTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Поиск...',
                    hintStyle: const TextStyle(color: AppColors.darkTextTertiary, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.darkTextSecondary),
                    filled: true,
                    fillColor: AppColors.darkSurfaceVariant,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.darkBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_selectedIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilledButton.icon(
                            onPressed: _deleteSelected,
                            icon: const Icon(Icons.delete, size: 14),
                            label: Text('Удалить (${_selectedIds.length})', style: const TextStyle(fontSize: 12)),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: _totalCount > 0 ? _confirmDeleteAllInTable : null,
                        icon: const Icon(Icons.delete_sweep, size: 14, color: AppColors.errorLight),
                        label: const Text('Очистить', style: TextStyle(color: AppColors.errorLight, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedTableLabel ?? '',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.darkTextPrimary)),
                    Text('$_totalCount записей • Таблица: $_selectedTable',
                        style: const TextStyle(fontSize: 12, color: AppColors.darkTextTertiary)),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 220,
                  height: 38,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                    style: const TextStyle(fontSize: 13, color: AppColors.darkTextPrimary),
                    decoration: InputDecoration(
                      hintText: 'Поиск...',
                      hintStyle: const TextStyle(color: AppColors.darkTextTertiary, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.darkTextSecondary),
                      filled: true,
                      fillColor: AppColors.darkSurfaceVariant,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.darkBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _fetchPage,
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Обновить',
                  style: IconButton.styleFrom(foregroundColor: AppColors.darkTextSecondary),
                ),
                if (_selectedIds.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _deleteSelected,
                    icon: const Icon(Icons.delete, size: 16),
                    label: Text('Удалить (${_selectedIds.length})'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _totalCount > 0 ? _confirmDeleteAllInTable : null,
                  icon: const Icon(Icons.delete_sweep, size: 16, color: AppColors.errorLight),
                  label: const Text('Очистить таблицу',
                      style: TextStyle(color: AppColors.errorLight, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ));
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.errorLight),
            const SizedBox(height: 16),
            const Text('Ошибка загрузки', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.errorLight)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(_error ?? '',
                  style: const TextStyle(fontSize: 12, color: AppColors.errorLight)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Возможно таблица не существует или нет прав.\n'
              'Для auth.users создайте VIEW: auth_users_view',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.darkTextTertiary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchPage,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Повторить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTable() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox, size: 48, color: AppColors.darkTextTertiary),
          const SizedBox(height: 12),
          Text('Таблица пустая',
              style: TextStyle(fontSize: 15, color: AppColors.darkTextSecondary)),
        ],
      ),
    );
  }

  Widget _buildMobileDataList(List<Map<String, dynamic>> filtered) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final row = filtered[index];
        final id = (row['id'] ?? row['uid'] ?? '').toString();
        final isSelected = _selectedIds.contains(id);

        final titleCandidate = row['name'] ?? row['title'] ?? row['label'] ?? row['email'] ?? row['phone'] ?? id;
        final subtitleCandidate = row['description'] ?? row['status'] ?? row['created_at'] ?? '';

        return Card(
          color: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.darkBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showRowDetailsBottomSheet(row),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (id.isNotEmpty)
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedIds.add(id);
                                } else {
                                  _selectedIds.remove(id);
                                }
                              });
                            },
                            activeColor: AppColors.primary,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          titleCandidate.toString(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkTextPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.darkTextTertiary,
                        size: 20,
                      ),
                    ],
                  ),
                  if (titleCandidate.toString() != id && id.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'ID: $id',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppColors.primaryLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (subtitleCandidate.toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formatValue(subtitleCandidate),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.darkTextSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildMiniFieldGrid(row, titleCandidate.toString(), id),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniFieldGrid(Map<String, dynamic> row, String title, String id) {
    final items = <Widget>[];
    int count = 0;
    for (final entry in row.entries) {
      final key = entry.key;
      final val = entry.value;
      if (key == 'id' || key == 'uid' || val == null) continue;
      if (entry.value.toString() == title) continue;
      if (val is Map || val is List || val.toString().length > 50) continue;

      items.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              key.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.darkTextTertiary,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              _formatValue(val),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.darkTextSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
      count++;
      if (count >= 4) break;
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.8,
      mainAxisSpacing: 8,
      crossAxisSpacing: 12,
      children: items,
    );
  }

  void _showRowDetailsBottomSheet(Map<String, dynamic> row) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.darkBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primaryLight),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Детали записи',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkTextPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        tooltip: 'Копировать JSON',
                        onPressed: () {
                          final jsonStr = row.toString();
                          Clipboard.setData(ClipboardData(text: jsonStr));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Копия JSON сохранена в буфер'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.darkBorder),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: row.length,
                    itemBuilder: (context, index) {
                      final key = row.keys.elementAt(index);
                      final val = row[key];
                      final valStr = _formatValue(val);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.darkSurfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.darkBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    key.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.darkTextTertiary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SelectableText(
                                    valStr,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: val == null ? AppColors.darkTextTertiary : AppColors.darkTextPrimary,
                                      fontFamily: key == 'id' || key == 'uid' ? 'monospace' : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.content_copy_rounded, size: 16),
                              color: AppColors.darkTextSecondary,
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: val?.toString() ?? ''));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Поле $key скопировано'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDataTable(List<Map<String, dynamic>> filtered) {
    final columns = _rows.isNotEmpty ? _rows.first.keys.toList() : <String>[];
    const double cellWidth = 180;
    const double checkWidth = 50;
    final double tableWidth = checkWidth + columns.length * cellWidth;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        child: Column(
          children: [
            // ── Header row ──
            Container(
              color: AppColors.darkSurfaceVariant,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: checkWidth,
                    child: Center(
                      child: Checkbox(
                        value: _selectAll,
                        onChanged: (v) {
                          setState(() {
                            _selectAll = v ?? false;
                            if (_selectAll) {
                              _selectedIds = filtered
                                  .map((r) => (r['id'] ?? r['uid'] ?? '').toString())
                                  .where((id) => id.isNotEmpty)
                                  .toSet();
                            } else {
                              _selectedIds.clear();
                            }
                          });
                        },
                        activeColor: AppColors.primary,
                      ),
                    ),
                  ),
                  ...columns.map((col) => SizedBox(
                        width: cellWidth,
                        child: Text(
                          col.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkTextSecondary,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.darkBorder),

            // ── Data rows ──
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final row = filtered[index];
                  final id = (row['id'] ?? row['uid'] ?? '').toString();
                  final isSelected = _selectedIds.contains(id);

                  return InkWell(
                    onTap: id.isEmpty ? null : () {
                      setState(() {
                        if (isSelected) {
                          _selectedIds.remove(id);
                        } else {
                          _selectedIds.add(id);
                        }
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : index.isEven
                                ? Colors.transparent
                                : Colors.white.withValues(alpha: 0.02),
                        border: const Border(
                          bottom: BorderSide(color: AppColors.darkBorder, width: 0.5),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: checkWidth,
                            child: Center(
                              child: Checkbox(
                                value: isSelected,
                                onChanged: id.isEmpty ? null : (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedIds.add(id);
                                    } else {
                                      _selectedIds.remove(id);
                                    }
                                  });
                                },
                                activeColor: AppColors.primary,
                              ),
                            ),
                          ),
                          ...columns.map((col) {
                            final val = row[col];
                            return SizedBox(
                              width: cellWidth,
                              child: Text(
                                _formatValue(val),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: val == null
                                      ? AppColors.darkTextTertiary
                                      : col == 'id'
                                          ? AppColors.primaryLight
                                          : AppColors.darkTextSecondary,
                                  fontFamily: col == 'id' ? 'monospace' : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (_totalCount / _pageSize).ceil();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        border: Border(top: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Row(
        children: [
          Text(
            'Показано ${_page * _pageSize + 1}–${(_page * _pageSize + _rows.length).clamp(0, _totalCount)} из $_totalCount',
            style: const TextStyle(fontSize: 12, color: AppColors.darkTextTertiary),
          ),
          const Spacer(),
          IconButton(
            onPressed: _page > 0 ? () { setState(() => _page--); _fetchPage(); } : null,
            icon: const Icon(Icons.chevron_left, size: 20),
            color: AppColors.darkTextPrimary,
            disabledColor: AppColors.darkTextTertiary.withValues(alpha: 0.5),
          ),
          Text('${_page + 1} / $totalPages',
              style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary)),
          IconButton(
            onPressed: _page < totalPages - 1 ? () { setState(() => _page++); _fetchPage(); } : null,
            icon: const Icon(Icons.chevron_right, size: 20),
            color: AppColors.darkTextPrimary,
            disabledColor: AppColors.darkTextTertiary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty || _selectedTable == null) return;

    final confirmed = await _showConfirmDialog(
      'Удалить ${_selectedIds.length} записей?',
      'Это действие необратимо. Записи будут удалены из таблицы "$_selectedTable".',
    );
    if (!confirmed) return;

    try {
      if (_isAuth) {
        // Clean up dependent tables first (FK constraints)
        for (final uid in _selectedIds) {
          for (final depTable in ['customers', 'couriers', 'employees']) {
            try {
              await _supabase.from(depTable).delete().eq('user_id', uid);
            } catch (_) {}
            try {
              await _supabase.from(depTable).delete().eq('id', uid);
            } catch (_) {}
          }
          try {
            await _supabase.auth.admin.deleteUser(uid);
          } catch (_) {}
        }
      } else {
        await _supabase
            .from(_selectedTable!)
            .delete()
            .inFilter('id', _selectedIds.toList());
      }

      _selectedIds.clear();
      _selectAll = false;
      await _fetchPage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Удалено успешно'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteAllInTable() async {
    if (_selectedTable == null) return;

    final confirmed = await _showConfirmDialog(
      'Очистить таблицу "$_selectedTable"?',
      'Все $_totalCount записей будут УДАЛЕНЫ. Это действие необратимо!',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      if (_isAuth) {
        // Clean up ALL dependent tables first (FK constraints)
        final depTables = [
          'delivery_order_item_modifiers',
          'delivery_order_messages', 'delivery_order_ratings',
          'delivery_order_items', 'delivery_orders',
          'courier_locations', 'courier_earnings', 'couriers',
          'sale_items', 'sales', 'cart_items',
          'employee_expenses', 'employees', 'roles',
          'customers', 'clients',
        ];
        for (final t in depTables) {
          try {
            await _supabase.from(t).delete().not('id', 'is', null);
          } catch (_) {}
        }
        // Now delete auth users
        final allUsers = await _supabase.auth.admin.listUsers();
        for (final user in allUsers) {
          try {
            await _supabase.auth.admin.deleteUser(user.id);
          } catch (_) {}
        }
      } else {
        // Clear dependent child tables first (FK constraints)
        final deps = _getDependentTables(_selectedTable!);
        for (final dep in deps) {
          try {
            await _supabase.from(dep).delete().not('id', 'is', null);
          } catch (_) {}
        }
        // Then clear the target table
        await _supabase
            .from(_selectedTable!)
            .delete()
            .not('id', 'is', null);
      }

      await _fetchPage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Таблица "$_selectedTable" очищена'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _confirmWipeAll() async {
    final confirmed = await _showConfirmDialog(
      '⚠️ ПОЛНАЯ ОЧИСТКА БАЗЫ',
      'Это удалит ВСЕ данные из ВСЕХ таблиц:\n'
      '• Пользователи\n• Компании\n• Склады\n• Товары\n'
      '• Заказы\n• Курьеры\n• Продажи\n\n'
      'Вы ТОЧНО уверены?',
      destructive: true,
    );
    if (!confirmed) return;

    // Second confirmation
    final reallyConfirmed = await _showConfirmDialog(
      '🔴 ПОСЛЕДНЕЕ ПРЕДУПРЕЖДЕНИЕ',
      'ВСЕ ДАННЫЕ БУДУТ УДАЛЕНЫ БЕЗВОЗВРАТНО.\n\nПродолжить?',
      destructive: true,
    );
    if (!reallyConfirmed) return;

    // Wipe order matters — children/leaf tables first, parents last
    // Based on powersync_schema.dart + delivery tables
    final tablesToWipe = [
      // Delivery deep children
      'delivery_order_item_modifiers',
      'delivery_order_messages',
      'delivery_order_ratings',
      'delivery_order_items',
      'delivery_orders',
      'courier_locations',
      'courier_earnings',
      'couriers',
      // Sales
      'sale_items',
      'sales',
      'cart_items',
      // Products deep children
      'product_modifiers',
      'product_modifier_groups',
      'product_images',
      'modifier_options',
      'modifier_groups',
      'product_prices',
      'products',
      // Categories
      'warehouse_store_categories',
      'store_categories',
      'categories',
      // Warehouse operations — items first
      'arrival_items',
      'arrivals',
      'write_off_items',
      'write_offs',
      'transfer_items',
      'transfers',
      'audit_items',
      'audits',
      // Services & clients
      'service_requests',
      'services',
      'clients',
      // Employees & expenses
      'employee_expenses',
      'employees',
      'roles',
      // Payment
      'payment_methods',
      // Warehouse & company hierarchy
      'warehouse_settings',
      'warehouse_groups',
      'warehouses',
      'companies',
      'customers',
    ];

    int deleted = 0;
    int errors = 0;
    final failedTables = <String>[];

    setState(() { _wiping = true; _wipingStatus = 'Проход 1: Начинаю...'; });

    // Pass 1
    for (int i = 0; i < tablesToWipe.length; i++) {
      final table = tablesToWipe[i];
      if (mounted) {
        setState(() => _wipingStatus = 'Проход 1: ${i + 1}/${tablesToWipe.length} — $table');
      }
      try {
        await _supabase
            .from(table)
            .delete()
            .not('id', 'is', null);
        deleted++;
      } catch (_) {
        failedTables.add(table);
      }
    }

    // Pass 2 — retry failed tables (FK deps should be cleared now)
    if (failedTables.isNotEmpty) {
      if (mounted) {
        setState(() => _wipingStatus = 'Проход 2: Повторяю ${failedTables.length} таблиц...');
      }
      for (final table in failedTables) {
        try {
          await _supabase
              .from(table)
              .delete()
              .not('id', 'is', null);
          deleted++;
        } catch (_) {
          errors++;
        }
      }
    }

    // Delete auth users
    if (mounted) setState(() => _wipingStatus = 'Удаляю аккаунты...');
    try {
      final users = await _supabase.auth.admin.listUsers();
      for (final user in users) {
        await _supabase.auth.admin.deleteUser(user.id);
      }
    } catch (_) {
      errors++;
    }

    if (mounted) {
      setState(() { _wiping = false; _wipingStatus = ''; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Очистка завершена: $deleted таблиц, $errors ошибок'),
          backgroundColor: errors == 0 ? AppColors.success : AppColors.warning,
          duration: const Duration(seconds: 5),
        ),
      );
      // Reload current table if any
      if (_selectedTable != null) _fetchPage();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // FK DEPENDENCY MAP
  // ═══════════════════════════════════════════════════════════

  /// Returns child tables that must be cleared before [table] can be deleted.
  List<String> _getDependentTables(String table) {
    const deps = <String, List<String>>{
      'companies': [
        'delivery_order_item_modifiers', 'delivery_order_messages',
        'delivery_order_ratings', 'delivery_order_items', 'delivery_orders',
        'courier_locations', 'courier_earnings', 'couriers',
        'sale_items', 'sales', 'cart_items',
        'product_modifiers', 'product_modifier_groups', 'product_images',
        'modifier_options', 'modifier_groups', 'product_prices', 'products',
        'warehouse_store_categories', 'store_categories', 'categories',
        'arrival_items', 'arrivals', 'write_off_items', 'write_offs',
        'transfer_items', 'transfers', 'audit_items', 'audits',
        'service_requests', 'services', 'clients',
        'employee_expenses', 'employees', 'roles',
        'payment_methods', 'warehouse_settings', 'warehouse_groups', 'warehouses',
      ],
      'warehouses': [
        'delivery_order_item_modifiers', 'delivery_order_messages',
        'delivery_order_ratings', 'delivery_order_items', 'delivery_orders',
        'sale_items', 'sales', 'cart_items',
        'product_modifiers', 'product_modifier_groups', 'product_images',
        'product_prices', 'products',
        'warehouse_store_categories', 'categories',
        'arrival_items', 'arrivals', 'write_off_items', 'write_offs',
        'transfer_items', 'transfers', 'audit_items', 'audits',
        'warehouse_settings', 'warehouse_groups',
      ],
      'products': [
        'delivery_order_item_modifiers', 'delivery_order_items',
        'sale_items', 'cart_items',
        'product_modifiers', 'product_modifier_groups',
        'product_images', 'product_prices',
      ],
      'categories': ['products', 'product_prices', 'product_images',
        'product_modifiers', 'product_modifier_groups', 'sale_items',
        'delivery_order_items', 'delivery_order_item_modifiers'],
      'delivery_orders': [
        'delivery_order_item_modifiers', 'delivery_order_messages',
        'delivery_order_ratings', 'delivery_order_items',
      ],
      'sales': ['sale_items'],
      'arrivals': ['arrival_items'],
      'write_offs': ['write_off_items'],
      'transfers': ['transfer_items'],
      'audits': ['audit_items'],
      'services': ['service_requests'],
      'modifier_groups': ['modifier_options', 'product_modifiers', 'product_modifier_groups'],
      'couriers': ['courier_locations', 'courier_earnings', 'delivery_orders'],
      'customers': ['delivery_orders'],
      'employees': ['employee_expenses'],
    };
    return deps[table] ?? [];
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════

  String _formatValue(dynamic val) {
    if (val == null) return 'null';
    if (val is String && val.length > 100) return '${val.substring(0, 100)}...';
    if (val is Map || val is List) return val.toString().length > 100
        ? '${val.toString().substring(0, 100)}...'
        : val.toString();
    // Try to format dates
    if (val is String && val.contains('T') && val.contains(':')) {
      try {
        final dt = DateTime.parse(val);
        return DateFormat('dd.MM.yyyy HH:mm').format(dt.toLocal());
      } catch (_) {}
    }
    return val.toString();
  }

  Future<bool> _showConfirmDialog(String title, String message,
      {bool destructive = false}) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.darkSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.darkBorder),
            ),
            title: Text(title,
                style: TextStyle(
                  color: destructive ? AppColors.errorLight : AppColors.darkTextPrimary,
                  fontWeight: FontWeight.w700,
                )),
            content: Text(message,
                style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: TextButton.styleFrom(foregroundColor: AppColors.darkTextSecondary),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      destructive ? AppColors.error : AppColors.primary,
                ),
                child: Text(destructive ? 'УДАЛИТЬ' : 'Да'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

// ═══════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════

class _TableGroup {
  final String label;
  final IconData icon;
  final List<_TableDef> tables;
  const _TableGroup(this.label, this.icon, this.tables);
}

class _TableDef {
  final String key;
  final String label;
  final IconData icon;
  final bool isAuth;
  final bool isStorage;
  const _TableDef(this.key, this.label, this.icon,
      {this.isAuth = false, this.isStorage = false});
}
