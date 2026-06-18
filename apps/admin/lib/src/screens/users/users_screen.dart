import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:intl/intl.dart';
import '../../widgets/admin_page_body.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  bool _loading = true;
  String _searchQuery = '';

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _couriers = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _authUsers = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _roles = [];
  double _globalCourierEarningRate = 0.90;
  String? _authError;

  final Set<String> _selectedAuthIds = {};
  final Set<String> _selectedCustomerIds = {};
  final Set<String> _selectedCourierIds = {};
  final Set<String> _selectedEmployeeIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update search hints/actions
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _authError = null;
    });

    try {
      // 1. Fetch Auth Users first (to resolve email lookup locally)
      List<Map<String, dynamic>> authList = [];
      try {
        final users = await _supabase.auth.admin.listUsers();
        authList = users
            .map((u) => {
                  'id': u.id,
                  'email': u.email ?? '',
                  'phone': u.phone ?? '',
                  'created_at': u.createdAt,
                  'last_sign_in': u.lastSignInAt ?? '',
                  'role': u.role ?? '',
                })
            .toList();
      } catch (e) {
        _authError = 'Нет доступа к Auth Admin API (требуется service_role)';
        debugPrint('Auth Admin API error: $e');
      }

      // 2. Fetch Customers (self-contained)
      final customersData = await _supabase
          .from('customers')
          .select()
          .order('created_at', ascending: false);

      // 3. Fetch Couriers (joined with warehouses/courier_warehouse)
      final couriersData = await _supabase
          .from('couriers')
          .select(
              '*, courier_warehouse(warehouse_id, is_active, warehouses(name))')
          .order('created_at', ascending: false);

      // 4. Fetch Employees
      final employeesData = await _supabase
          .from('employees')
          .select('*')
          .order('created_at', ascending: false);

      // 5. Fetch Warehouses for dropdowns/linkages
      final warehousesData = await _supabase
          .from('warehouses')
          .select('id, name, address, organization_id')
          .order('name');

      // 6. Fetch Roles for employee creation
      final rolesData = await _supabase
          .from('roles')
          .select('id, name, company_id')
          .order('name');

      double globalRate = 0.90;
      try {
        final settingsData = await _supabase
            .from('system_settings')
            .select('courier_earning_rate')
            .eq('id', 'default')
            .maybeSingle();
        if (settingsData != null) {
          globalRate = (settingsData['courier_earning_rate'] as num?)?.toDouble() ?? 0.90;
        }
      } catch (_) {}

      setState(() {
        _customers = List<Map<String, dynamic>>.from(customersData);
        _couriers = List<Map<String, dynamic>>.from(couriersData);
        _employees = List<Map<String, dynamic>>.from(employeesData);
        _warehouses = List<Map<String, dynamic>>.from(warehousesData);
        _roles = List<Map<String, dynamic>>.from(rolesData);
        _authUsers = authList;
        _globalCourierEarningRate = globalRate;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки данных: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Lookup email for a user from in-memory authUsers list
  String _getEmailForUserId(String? userId) {
    if (userId == null || _authUsers.isEmpty) return '';
    try {
      final match = _authUsers.firstWhere(
        (u) => u['id'] == userId,
        orElse: () => {},
      );
      return match['email'] ?? '';
    } catch (_) {
      return '';
    }
  }

  // Filtered lists based on search query
  List<Map<String, dynamic>> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      final email = _getEmailForUserId(c['user_id']).toLowerCase();
      return name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          email.contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredCouriers {
    if (_searchQuery.isEmpty) return _couriers;
    return _couriers.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      final email = _getEmailForUserId(c['user_id']).toLowerCase();
      final key = (c['access_key'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          key.contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    if (_searchQuery.isEmpty) return _employees;
    return _employees.where((e) {
      final name = (e['name'] ?? '').toString().toLowerCase();
      final phone = (e['phone'] ?? '').toString().toLowerCase();
      final email = _getEmailForUserId(e['user_id']).toLowerCase();
      final role = (e['role'] ?? '').toString().toLowerCase();
      final wh = _getEmployeeWarehouseNames(e).toLowerCase();
      return name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          role.contains(_searchQuery) ||
          wh.contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredAuthUsers {
    if (_searchQuery.isEmpty) return _authUsers;
    return _authUsers.where((u) {
      final email = (u['email'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString().toLowerCase();
      final id = (u['id'] ?? '').toString().toLowerCase();
      return email.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          id.contains(_searchQuery);
    }).toList();
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
                  hint: _getSearchHint(),
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
              if (!isMobile) ...[
                if (_hasAnySelected()) ...[
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _deleteSelectedUsers,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: Text('Удалить (${_getSelectedCount()})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                if (_tabController.index == 2) ...[
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddCourierDialog(),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Добавить курьера'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                if (_tabController.index == 3) ...[
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEmployeeDialog(),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Добавить сотрудника'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                const SizedBox(width: 16),
                IconButton(
                  tooltip: 'Обновить данные',
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded,
                      color: AppColors.darkTextSecondary),
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
          if (isMobile) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (_hasAnySelected()) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _deleteSelectedUsers,
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: Text('Удалить (${_getSelectedCount()})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (_tabController.index == 2)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddCourierDialog(),
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Добавить курьера'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (_tabController.index == 3)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddEmployeeDialog(),
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Добавить сотрудника'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Tab Bar navigation
          Container(
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.darkBorder, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: isMobile,
              tabAlignment: isMobile ? TabAlignment.start : TabAlignment.fill,
              labelColor: AppColors.primaryLight,
              unselectedLabelColor: AppColors.darkTextSecondary,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Все (${_authUsers.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline, size: 18),
                      const SizedBox(width: 8),
                      Text('Клиенты (${_customers.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delivery_dining_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Курьеры (${_couriers.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.badge_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Сотрудники (${_employees.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tab views
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAuthUsersTab(isMobile),
                      _buildCustomersTab(isMobile),
                      _buildCouriersTab(isMobile),
                      _buildEmployeesTab(isMobile),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _getSearchHint() {
    switch (_tabController.index) {
      case 0:
        return 'Поиск по email, телефону или ID...';
      case 1:
      case 2:
        return 'Поиск по имени, телефону или email...';
      case 3:
        return 'Поиск по имени, роли или складу...';
      default:
        return 'Поиск...';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // TAB BUILDERS
  // ═══════════════════════════════════════════════════════════

  Widget _buildAuthUsersTab(bool isMobile) {
    if (_authError != null) {
      return AdminEmptyState(
        icon: Icons.lock_person_rounded,
        title: 'Доступ ограничен',
        subtitle: _authError,
      );
    }
    if (_filteredAuthUsers.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'Учетные записи не найдены',
        subtitle: 'Попробуйте изменить поисковый запрос',
      );
    }

    if (isMobile) {
      return ListView.separated(
        itemCount: _filteredAuthUsers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, idx) =>
            _buildAuthUserMobileCard(_filteredAuthUsers[idx]),
      );
    }

    return _buildDesktopTable(
      columns: const [
        'ID',
        'Email',
        'Телефон',
        'Создан',
        'Последний вход',
        'Действия'
      ],
      rows: _filteredAuthUsers.map((u) {
        final id = u['id'] as String;
        final isSelected = _selectedAuthIds.contains(id);

        return DataRow(
          selected: isSelected,
          onSelectChanged: (selected) {
            setState(() {
              if (selected == true) {
                _selectedAuthIds.add(id);
              } else {
                _selectedAuthIds.remove(id);
              }
            });
          },
          cells: [
            DataCell(
              SelectableText(
                id,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppColors.darkTextSecondary),
              ),
            ),
            DataCell(Text(u['email']?.isEmpty == true ? '—' : u['email'],
                style: const TextStyle(color: Colors.white))),
            DataCell(Text(u['phone']?.isEmpty == true ? '—' : u['phone'],
                style: const TextStyle(color: Colors.white))),
            DataCell(Text(_formatDate(u['created_at']),
                style: const TextStyle(color: AppColors.darkTextSecondary))),
            DataCell(Text(_formatDate(u['last_sign_in']),
                style: const TextStyle(color: AppColors.darkTextSecondary))),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded,
                        color: AppColors.primaryLight, size: 20),
                    onPressed: () => _showAuthUserDetail(u),
                    tooltip: 'Детали',
                  ),
                  IconButton(
                    icon: const Icon(Icons.lock_reset_rounded,
                        color: AppColors.warningLight, size: 20),
                    onPressed: () => _showChangePasswordDialog(id,
                        u['email']?.isEmpty == true ? u['phone'] : u['email']),
                    tooltip: 'Сменить пароль',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever_rounded,
                        color: AppColors.errorLight, size: 20),
                    onPressed: () => _confirmDeleteUser(id, 'auth',
                        u['email'] ?? u['phone'] ?? 'Без контактов'),
                    tooltip: 'Удалить аккаунт',
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCustomersTab(bool isMobile) {
    if (_filteredCustomers.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.person_search_rounded,
        title: 'Клиенты не найдены',
        subtitle: 'Попробуйте изменить поисковый запрос',
      );
    }

    if (isMobile) {
      return ListView.separated(
        itemCount: _filteredCustomers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, idx) =>
            _buildCustomerMobileCard(_filteredCustomers[idx]),
      );
    }

    return _buildDesktopTable(
      columns: const ['Имя', 'Телефон', 'Email', 'Зарегистрирован', 'Действия'],
      rows: _filteredCustomers.map((c) {
        final id = c['id'] as String;
        final userId = c['user_id'] as String?;
        final name = c['name'] ?? '—';
        final phone = c['phone'] ?? '—';
        final email = _getEmailForUserId(userId);
        final displayEmail = email.isEmpty ? '—' : email;
        final isSelected = _selectedCustomerIds.contains(id);

        return DataRow(
          selected: isSelected,
          onSelectChanged: (selected) {
            setState(() {
              if (selected == true) {
                _selectedCustomerIds.add(id);
              } else {
                _selectedCustomerIds.remove(id);
              }
            });
          },
          cells: [
            DataCell(Text(name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500))),
            DataCell(Text(phone, style: const TextStyle(color: Colors.white))),
            DataCell(Text(displayEmail,
                style: const TextStyle(color: Colors.white))),
            DataCell(Text(_formatDate(c['created_at']),
                style: const TextStyle(color: AppColors.darkTextSecondary))),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded,
                        color: AppColors.primaryLight, size: 20),
                    onPressed: () => _showCustomerDetail(c),
                    tooltip: 'Детали',
                  ),
                  if (userId != null)
                    IconButton(
                      icon: const Icon(Icons.lock_reset_rounded,
                          color: AppColors.warningLight, size: 20),
                      onPressed: () => _showChangePasswordDialog(userId,
                          displayEmail.isNotEmpty ? displayEmail : phone),
                      tooltip: 'Сменить пароль',
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever_rounded,
                        color: AppColors.errorLight, size: 20),
                    onPressed: () =>
                        _confirmDeleteUser(userId, 'customer', name),
                    tooltip: 'Удалить клиента',
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCouriersTab(bool isMobile) {
    if (_filteredCouriers.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.person_search_rounded,
        title: 'Курьеры не найдены',
        subtitle: 'Попробуйте изменить поисковый запрос',
      );
    }

    if (isMobile) {
      return ListView.separated(
        itemCount: _filteredCouriers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, idx) =>
            _buildCourierMobileCard(_filteredCouriers[idx]),
      );
    }

    return _buildDesktopTable(
      columns: const [
        'Имя',
        'Телефон',
        'Ключ',
        'Ставка',
        'Статус',
        'Склады',
        'Действия'
      ],
      rows: _filteredCouriers.map((c) {
        final id = c['id'] as String;
        final name = c['name'] ?? '—';
        final phone = c['phone'] ?? '—';
        final key = c['access_key'] ?? '—';
        final courierRate = c['earning_rate'] as num?;
        final rate = courierRate != null
            ? '${(courierRate * 100).toStringAsFixed(0)}%'
            : '${(_globalCourierEarningRate * 100).toStringAsFixed(0)}% (сист.)';
        final isActive = c['is_active'] == true;
        final isSelected = _selectedCourierIds.contains(id);

        final linkedWarehouses = (c['courier_warehouse'] as List? ?? [])
            .where((w) => w['is_active'] == true)
            .toList();
        final warehouseNames = linkedWarehouses
            .map((w) => w['warehouses']?['name'] ?? '?')
            .join(', ');

        return DataRow(
          selected: isSelected,
          onSelectChanged: (selected) {
            setState(() {
              if (selected == true) {
                _selectedCourierIds.add(id);
              } else {
                _selectedCourierIds.remove(id);
              }
            });
          },
          cells: [
            DataCell(Text(name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500))),
            DataCell(Text(phone, style: const TextStyle(color: Colors.white))),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(key,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
              ),
            ),
            DataCell(Text(rate,
                style: const TextStyle(
                    color: AppColors.successLight,
                    fontWeight: FontWeight.bold))),
            DataCell(_buildStatusBadge(isActive)),
            DataCell(Text(warehouseNames.isEmpty ? '—' : warehouseNames,
                style: const TextStyle(
                    color: AppColors.darkTextSecondary, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis)),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded,
                        color: AppColors.primaryLight, size: 20),
                    onPressed: () => _showCourierDetail(c),
                    tooltip: 'Детали',
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: AppColors.darkTextSecondary),
                    color: AppColors.darkSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.darkBorder),
                    ),
                    onSelected: (val) {
                      if (val == 'rate') _showEditRateDialog(c);
                      if (val == 'transport') _showEditTransportDialog(c);
                      if (val == 'key') _regenerateKey(c);
                      if (val == 'warehouses') _showLinkWarehouseDialog(c);
                      if (val == 'toggle') _toggleActive(c);
                      if (val == 'password' && c['user_id'] != null) {
                        _showChangePasswordDialog(
                            c['user_id'],
                            _getEmailForUserId(c['user_id']).isNotEmpty
                                ? _getEmailForUserId(c['user_id'])
                                : phone);
                      }
                      if (val == 'delete') {
                        _confirmDeleteUser(c['user_id'], 'courier', name);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'rate',
                        child: Row(children: [
                          Icon(Icons.percent_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Изменить ставку')
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'transport',
                        child: Row(children: [
                          Icon(Icons.local_shipping_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Транспорт')
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'key',
                        child: Row(children: [
                          Icon(Icons.vpn_key_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Новый ключ доступа')
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'warehouses',
                        child: Row(children: [
                          Icon(Icons.store_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Привязать склады')
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(children: [
                          Icon(
                              isActive
                                  ? Icons.block_rounded
                                  : Icons.check_circle_rounded,
                              size: 18),
                          const SizedBox(width: 10),
                          Text(isActive ? 'Отключить' : 'Активировать')
                        ]),
                      ),
                      if (c['user_id'] != null)
                        const PopupMenuItem(
                          value: 'password',
                          child: Row(children: [
                            Icon(Icons.lock_reset_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('Сменить пароль')
                          ]),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_forever_rounded,
                              size: 18, color: AppColors.errorLight),
                          SizedBox(width: 10),
                          Text('Удалить курьера',
                              style: TextStyle(color: AppColors.errorLight))
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildEmployeesTab(bool isMobile) {
    if (_filteredEmployees.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.person_search_rounded,
        title: 'Сотрудники не найдены',
        subtitle: 'Попробуйте изменить поисковый запрос',
      );
    }

    if (isMobile) {
      return ListView.separated(
        itemCount: _filteredEmployees.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, idx) =>
            _buildEmployeeMobileCard(_filteredEmployees[idx]),
      );
    }

    return _buildDesktopTable(
      columns: const ['Имя', 'Телефон', 'Роль', 'Склад', 'Действия'],
      rows: _filteredEmployees.map((e) {
        final id = e['id'] as String;
        final name = e['name'] ?? '—';
        final phone = e['phone'] ?? '—';
        final role = _translateRole(e['role']);
        final wh = _getEmployeeWarehouseNames(e);
        final isSelected = _selectedEmployeeIds.contains(id);

        return DataRow(
          selected: isSelected,
          onSelectChanged: (selected) {
            setState(() {
              if (selected == true) {
                _selectedEmployeeIds.add(id);
              } else {
                _selectedEmployeeIds.remove(id);
              }
            });
          },
          cells: [
            DataCell(Text(name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500))),
            DataCell(Text(phone, style: const TextStyle(color: Colors.white))),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(role,
                    style: const TextStyle(
                        color: AppColors.infoLight,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            DataCell(Text(wh, style: const TextStyle(color: Colors.white))),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded,
                        color: AppColors.primaryLight, size: 20),
                    onPressed: () => _showEmployeeDetail(e),
                    tooltip: 'Детали',
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: AppColors.darkTextSecondary),
                    color: AppColors.darkSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.darkBorder),
                    ),
                    onSelected: (val) {
                      if (val == 'password' && e['user_id'] != null) {
                        _showChangePasswordDialog(
                            e['user_id'],
                            _getEmailForUserId(e['user_id']).isNotEmpty
                                ? _getEmailForUserId(e['user_id'])
                                : phone);
                      }
                      if (val == 'delete') {
                        _confirmDeleteUser(e['user_id'], 'employee', name);
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (e['user_id'] != null)
                        const PopupMenuItem(
                          value: 'password',
                          child: Row(children: [
                            Icon(Icons.lock_reset_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('Сменить пароль')
                          ]),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_forever_rounded,
                              size: 18, color: AppColors.errorLight),
                          SizedBox(width: 10),
                          Text('Удалить сотрудника',
                              style: TextStyle(color: AppColors.errorLight))
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDesktopTable(
      {required List<String> columns, required List<DataRow> rows}) {
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
            headingRowColor:
                WidgetStateProperty.all(AppColors.darkSurfaceVariant),
            dataRowColor: WidgetStateProperty.all(Colors.transparent),
            horizontalMargin: 20,
            columnSpacing: 30,
            columns: columns
                .map((col) => DataColumn(
                      label: Text(
                        col,
                        style: const TextStyle(
                            color: AppColors.darkTextSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ))
                .toList(),
            rows: rows,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // MOBILE CARDS WITH SELECTION
  // ═══════════════════════════════════════════════════════════

  Widget _buildAuthUserMobileCard(Map<String, dynamic> u) {
    final id = u['id'] as String;
    final isSelected = _selectedAuthIds.contains(id);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: isSelected,
            activeColor: AppColors.primary,
            onChanged: (selected) {
              setState(() {
                if (selected == true) {
                  _selectedAuthIds.add(id);
                } else {
                  _selectedAuthIds.remove(id);
                }
              });
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        u['email']?.isEmpty == true ? u['phone'] : u['email'],
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.info_outline_rounded,
                              color: AppColors.primaryLight, size: 20),
                          onPressed: () => _showAuthUserDetail(u),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.lock_reset_rounded,
                              color: AppColors.warningLight, size: 20),
                          onPressed: () => _showChangePasswordDialog(
                              id,
                              u['email']?.isEmpty == true
                                  ? u['phone']
                                  : u['email']),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.delete_forever_rounded,
                              color: AppColors.errorLight, size: 20),
                          onPressed: () => _confirmDeleteUser(id, 'auth',
                              u['email'] ?? u['phone'] ?? 'Без контактов'),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('ID: ${u['id']}',
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppColors.darkTextTertiary)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Создан: ${_formatDate(u['created_at'])}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.darkTextSecondary)),
                    if (u['last_sign_in'] != null)
                      Text('Вход: ${_formatDate(u['last_sign_in'])}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.darkTextSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerMobileCard(Map<String, dynamic> c) {
    final id = c['id'] as String;
    final userId = c['user_id'] as String?;
    final name = c['name'] ?? '—';
    final phone = c['phone'] ?? '—';
    final isSelected = _selectedCustomerIds.contains(id);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            activeColor: AppColors.primary,
            onChanged: (selected) {
              setState(() {
                if (selected == true) {
                  _selectedCustomerIds.add(id);
                } else {
                  _selectedCustomerIds.remove(id);
                }
              });
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 4),
                Text(phone,
                    style: const TextStyle(
                        color: AppColors.darkTextSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Дата: ${_formatDate(c['created_at'])}',
                    style: const TextStyle(
                        color: AppColors.darkTextTertiary, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded,
                color: AppColors.primaryLight, size: 20),
            onPressed: () => _showCustomerDetail(c),
          ),
          if (userId != null)
            IconButton(
              icon: const Icon(Icons.lock_reset_rounded,
                  color: AppColors.warningLight, size: 20),
              onPressed: () => _showChangePasswordDialog(
                  userId,
                  _getEmailForUserId(userId).isNotEmpty
                      ? _getEmailForUserId(userId)
                      : phone),
            ),
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded,
                color: AppColors.errorLight, size: 20),
            onPressed: () => _confirmDeleteUser(userId, 'customer', name),
          ),
        ],
      ),
    );
  }

  Widget _buildCourierMobileCard(Map<String, dynamic> c) {
    final id = c['id'] as String;
    final name = c['name'] ?? '—';
    final phone = c['phone'] ?? '—';
    final key = c['access_key'] ?? '—';
    final courierRate = c['earning_rate'] as num?;
    final rate = courierRate != null
        ? '${(courierRate * 100).toStringAsFixed(0)}%'
        : '${(_globalCourierEarningRate * 100).toStringAsFixed(0)}% (сист.)';
    final isActive = c['is_active'] == true;
    final isSelected = _selectedCourierIds.contains(id);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Checkbox(
              value: isSelected,
              activeColor: AppColors.primary,
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedCourierIds.add(id);
                  } else {
                    _selectedCourierIds.remove(id);
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    _buildStatusBadge(isActive),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(phone,
                        style: const TextStyle(
                            color: AppColors.darkTextSecondary, fontSize: 13)),
                    const Spacer(),
                    Text('Ставка: $rate',
                        style: const TextStyle(
                            color: AppColors.successLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Ключ: $key',
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              color: AppColors.primaryLight,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded,
                          color: AppColors.primaryLight, size: 18),
                      onPressed: () => _showCourierDetail(c),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 14),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded,
                          color: AppColors.darkTextSecondary),
                      color: AppColors.darkSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.darkBorder),
                      ),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      onSelected: (val) {
                        if (val == 'rate') _showEditRateDialog(c);
                        if (val == 'transport') _showEditTransportDialog(c);
                        if (val == 'key') _regenerateKey(c);
                        if (val == 'warehouses') _showLinkWarehouseDialog(c);
                        if (val == 'toggle') _toggleActive(c);
                        if (val == 'password' && c['user_id'] != null) {
                          _showChangePasswordDialog(
                              c['user_id'],
                              _getEmailForUserId(c['user_id']).isNotEmpty
                                  ? _getEmailForUserId(c['user_id'])
                                  : phone);
                        }
                        if (val == 'delete') {
                          _confirmDeleteUser(c['user_id'], 'courier', name);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'rate',
                          child: Row(children: [
                            Icon(Icons.percent_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('Изменить ставку')
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'transport',
                          child: Row(children: [
                            Icon(Icons.local_shipping_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('Транспорт')
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'key',
                          child: Row(children: [
                            Icon(Icons.vpn_key_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('Новый ключ доступа')
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'warehouses',
                          child: Row(children: [
                            Icon(Icons.store_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('Привязать склады')
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(children: [
                            Icon(
                                isActive
                                    ? Icons.block_rounded
                                    : Icons.check_circle_rounded,
                                size: 18),
                            const SizedBox(width: 10),
                            Text(isActive ? 'Отключить' : 'Активировать')
                          ]),
                        ),
                        if (c['user_id'] != null)
                          const PopupMenuItem(
                            value: 'password',
                            child: Row(children: [
                              Icon(Icons.lock_reset_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Сменить пароль')
                            ]),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_forever_rounded,
                                size: 18, color: AppColors.errorLight),
                            SizedBox(width: 10),
                            Text('Удалить курьера',
                                style: TextStyle(color: AppColors.errorLight))
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeMobileCard(Map<String, dynamic> e) {
    final id = e['id'] as String;
    final name = e['name'] ?? '—';
    final phone = e['phone'] ?? '—';
    final role = _translateRole(e['role']);
    final wh = _getEmployeeWarehouseNames(e);
    final isSelected = _selectedEmployeeIds.contains(id);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Checkbox(
              value: isSelected,
              activeColor: AppColors.primary,
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedEmployeeIds.add(id);
                  } else {
                    _selectedEmployeeIds.remove(id);
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(role,
                          style: const TextStyle(
                              color: AppColors.infoLight,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(phone,
                    style: const TextStyle(
                        color: AppColors.darkTextSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('Склад: $wh',
                          style: const TextStyle(
                              color: AppColors.darkTextTertiary, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.info_outline_rounded,
                              color: AppColors.primaryLight, size: 18),
                          onPressed: () => _showEmployeeDetail(e),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 14),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded,
                              color: AppColors.darkTextSecondary),
                          color: AppColors.darkSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: AppColors.darkBorder),
                          ),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onSelected: (val) {
                            if (val == 'password' && e['user_id'] != null) {
                              _showChangePasswordDialog(
                                  e['user_id'],
                                  _getEmailForUserId(e['user_id']).isNotEmpty
                                      ? _getEmailForUserId(e['user_id'])
                                      : phone);
                            }
                            if (val == 'delete') {
                              _confirmDeleteUser(
                                  e['user_id'], 'employee', name);
                            }
                          },
                          itemBuilder: (ctx) => [
                            if (e['user_id'] != null)
                              const PopupMenuItem(
                                value: 'password',
                                child: Row(children: [
                                  Icon(Icons.lock_reset_rounded, size: 18),
                                  SizedBox(width: 10),
                                  Text('Сменить пароль')
                                ]),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_forever_rounded,
                                    size: 18, color: AppColors.errorLight),
                                SizedBox(width: 10),
                                Text('Удалить сотрудника',
                                    style:
                                        TextStyle(color: AppColors.errorLight))
                              ]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DETAIL DIALOGS
  // ═══════════════════════════════════════════════════════════

  void _showAuthUserDetail(Map<String, dynamic> u) {
    _showDetailDialog(
      title: 'Учетная запись Auth',
      details: {
        'ID пользователя': u['id'] ?? '—',
        'Электронная почта': u['email']?.isEmpty == true ? '—' : u['email'],
        'Номер телефона': u['phone']?.isEmpty == true ? '—' : u['phone'],
        'Роль в системе': u['role'] ?? '—',
        'Дата регистрации': _formatDate(u['created_at']),
        'Последний вход': _formatDate(u['last_sign_in']),
      },
    );
  }

  void _showCustomerDetail(Map<String, dynamic> c) {
    final name = c['name'] ?? '—';
    final phone = c['phone'] ?? '—';
    final email = _getEmailForUserId(c['user_id']);

    _showDetailDialog(
      title: 'Профиль клиента AkJol Go',
      details: {
        'ID записи клиента': c['id'] ?? '—',
        'ID пользователя (Auth)': c['user_id'] ?? '—',
        'Имя': name,
        'Номер телефона': phone,
        'Электронная почта': email.isEmpty ? '—' : email,
        'Дефолтный адрес': c['default_address'] ?? '—',
        'Дата создания профиля': _formatDate(c['created_at']),
      },
    );
  }

  void _showCourierDetail(Map<String, dynamic> c) {
    final name = c['name'] ?? '—';
    final phone = c['phone'] ?? '—';
    final key = c['access_key'] ?? '—';
    final rate = '${(_globalCourierEarningRate * 100).toStringAsFixed(0)}%';
    final transports =
        (c['transport_types'] as List?)?.join(', ') ?? 'Велосипед';
    final email = _getEmailForUserId(c['user_id']);

    _showDetailDialog(
      title: 'Профиль курьера AkJol Pro',
      details: {
        'ID курьера': c['id'] ?? '—',
        'ID пользователя (Auth)': c['user_id'] ?? '—',
        'Имя курьера': name,
        'Номер телефона': phone,
        'Электронная почта': email.isEmpty ? '—' : email,
        'Код доступа (ключ)': key,
        'Процент заработка (ставка)': rate,
        'Типы транспорта': transports,
        'Статус активности': c['is_active'] == true ? 'Активен' : 'Отключен',
        'В сети (Online)': c['is_online'] == true ? 'Да' : 'Нет',
        'Баланс банка': '${c['bank_balance'] ?? 0} с',
        'Зарегистрирован': _formatDate(c['created_at']),
      },
    );
  }

  void _showEmployeeDetail(Map<String, dynamic> e) {
    final name = e['name'] ?? '—';
    final phone = e['phone'] ?? '—';
    final email = _getEmailForUserId(e['user_id']);
    final role = _translateRole(e['role']);
    final wh = _getEmployeeWarehouseNames(e);

    _showDetailDialog(
      title: 'Сотрудник TakEsep Warehouse',
      details: {
        'ID сотрудника': e['id'] ?? '—',
        'ID пользователя (Auth)': e['user_id'] ?? '—',
        'Имя сотрудника': name,
        'Номер телефона': phone,
        'Электронная почта': email.isEmpty ? '—' : email,
        'Роль на складе': role,
        'Склад привязки': wh,
        'ИНН': e['inn'] ?? '—',
        'Номер паспорта': e['passport_number'] ?? '—',
        'Паспорт выдан кем': e['passport_issued_by'] ?? '—',
        'Паспорт выдан когда': e['passport_issued_date'] ?? '—',
        'Зарплата тип': e['salary_type'] ?? '—',
        'Зарплата сумма': '${e['salary_amount'] ?? 0} с',
        'Дата привязки': _formatDate(e['created_at']),
      },
    );
  }

  void _showDetailDialog(
      {required String title, required Map<String, String> details}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.darkBorder)),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.darkTextPrimary, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          child: Scrollbar(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: details.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key,
                            style: const TextStyle(
                                color: AppColors.darkTextTertiary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        SelectableText(
                          entry.value,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: entry.key.contains('ID') ||
                                    entry.key.contains('ключ')
                                ? 'monospace'
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть',
                style: TextStyle(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CASCADE DELETE WORKFLOW
  // ═══════════════════════════════════════════════════════════

  Future<void> _deleteSingleUserCascade(String userId, String userType) async {
    // 1. Core user tables
    try {
      await _supabase.from('user_fcm_tokens').delete().eq('user_id', userId);
    } catch (_) {}
    try {
      await _supabase.from('favorites').delete().eq('user_id', userId);
    } catch (_) {}
    try {
      await _supabase.from('cart_drafts').delete().eq('user_id', userId);
    } catch (_) {}
    try {
      await _supabase
          .from('addresses')
          .update({'created_by': null}).eq('created_by', userId);
    } catch (_) {}
    try {
      await _supabase.from('user_profiles').delete().eq('id', userId);
    } catch (_) {}

    // 2. Customers cascade
    if (userType == 'customer' || userType == 'auth') {
      final cust = await _supabase
          .from('customers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      if (cust != null) {
        final custId = cust['id'];
        final orders = await _supabase
            .from('delivery_orders')
            .select('id')
            .eq('customer_id', custId);
        for (final o in orders) {
          final oId = o['id'];
          try {
            await _supabase
                .from('delivery_order_items')
                .delete()
                .eq('order_id', oId);
          } catch (_) {}
          try {
            await _supabase
                .from('delivery_order_messages')
                .delete()
                .eq('order_id', oId);
          } catch (_) {}
          try {
            await _supabase
                .from('delivery_order_ratings')
                .delete()
                .eq('order_id', oId);
          } catch (_) {}
          try {
            await _supabase
                .from('delivery_ratings')
                .delete()
                .eq('order_id', oId);
          } catch (_) {}
          try {
            await _supabase
                .from('delivery_order_status_history')
                .delete()
                .eq('order_id', oId);
          } catch (_) {}
          try {
            await _supabase.from('transactions').delete().eq('order_id', oId);
          } catch (_) {}
        }
        try {
          await _supabase
              .from('delivery_ratings')
              .delete()
              .eq('customer_id', custId);
        } catch (_) {}
        try {
          await _supabase
              .from('delivery_order_ratings')
              .delete()
              .eq('customer_id', custId);
        } catch (_) {}
        try {
          await _supabase
              .from('delivery_orders')
              .delete()
              .eq('customer_id', custId);
        } catch (_) {}
        try {
          await _supabase
              .from('customer_addresses')
              .delete()
              .eq('customer_id', custId);
        } catch (_) {}
        try {
          await _supabase.from('customers').delete().eq('id', custId);
        } catch (_) {}
      }
    }

    // 3. Couriers cascade
    if (userType == 'courier' || userType == 'auth') {
      final cour = await _supabase
          .from('couriers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      if (cour != null) {
        final courId = cour['id'];
        try {
          await _supabase
              .from('courier_locations')
              .delete()
              .eq('courier_id', courId);
        } catch (_) {}
        try {
          await _supabase
              .from('delivery_orders')
              .update({'courier_id': null}).eq('courier_id', courId);
        } catch (_) {}
        try {
          await _supabase.from('couriers').delete().eq('id', courId);
        } catch (_) {}
      }
    }

    // 4. Employees cascade
    if (userType == 'employee' || userType == 'auth') {
      final emp = await _supabase
          .from('employees')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      if (emp != null) {
        final empId = emp['id'];
        try {
          await _supabase
              .from('employee_expenses')
              .delete()
              .eq('employee_id', empId);
        } catch (_) {}
        try {
          await _supabase.from('employees').delete().eq('id', empId);
        } catch (_) {}
      }
    }

    // 5. Delete user credentials from Supabase Auth
    await _supabase.auth.admin.deleteUser(userId);
  }

  Future<void> _confirmDeleteUser(
      String? userId, String userType, String userName) async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Не удалось определить ID пользователя'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.darkBorder)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.errorLight),
            const SizedBox(width: 10),
            const Text('Удаление аккаунта',
                style: TextStyle(
                    color: AppColors.darkTextPrimary,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Вы действительно хотите удалить пользователя "$userName"?',
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            Text(
              'Это действие каскадно удалит профиль, сессии, FCM-токены, корзину, привязки курьера/склада и учетные данные для авторизации в Supabase Auth.',
              style: TextStyle(
                  color: AppColors.errorLight.withValues(alpha: 0.85),
                  fontSize: 13),
            ),
            const SizedBox(height: 10),
            const Text('Данное действие НЕОБРАТИМО.',
                style: TextStyle(
                    color: AppColors.errorLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена',
                style: TextStyle(color: AppColors.darkTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить навсегда'),
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
                Text('Выполняется каскадное удаление...',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await _deleteSingleUserCascade(userId, userType);

      // Dismiss loading overlay safely
      if (mounted) Navigator.of(context).pop();

      // Success notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Пользователь "$userName" успешно удален из системы'),
            backgroundColor: AppColors.success,
          ),
        );
      }

      // Reload data
      _loadData();
    } catch (e) {
      // Dismiss loading overlay safely
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedUsers() async {
    final int index = _tabController.index;
    List<String> idsToDelete = [];
    String userType = '';
    String title = '';

    if (index == 0) {
      idsToDelete = _selectedAuthIds.toList();
      userType = 'auth';
      title = 'учетных записей Auth';
    } else if (index == 1) {
      idsToDelete = _selectedCustomerIds.toList();
      userType = 'customer';
      title = 'клиентов';
    } else if (index == 2) {
      idsToDelete = _selectedCourierIds.toList();
      userType = 'courier';
      title = 'курьеров';
    } else if (index == 3) {
      idsToDelete = _selectedEmployeeIds.toList();
      userType = 'employee';
      title = 'сотрудников';
    }

    if (idsToDelete.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.darkBorder)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.errorLight),
            const SizedBox(width: 10),
            const Text('Групповое удаление',
                style: TextStyle(
                    color: AppColors.darkTextPrimary,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Вы действительно хотите удалить выбранные элементы ($title: ${idsToDelete.length} шт.)?',
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            Text(
              'Это действие каскадно удалит профили, сессии, FCM-токены, привязки и учетные данные для авторизации.',
              style: TextStyle(
                  color: AppColors.errorLight.withValues(alpha: 0.85),
                  fontSize: 13),
            ),
            const SizedBox(height: 10),
            const Text('Данное действие НЕОБРАТИМО.',
                style: TextStyle(
                    color: AppColors.errorLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена',
                style: TextStyle(color: AppColors.darkTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить выбранные'),
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
                Text('Выполняется групповое удаление...',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      for (final id in idsToDelete) {
        if (userType == 'auth') {
          await _deleteSingleUserCascade(id, 'auth');
        } else if (userType == 'customer') {
          final c = _customers.firstWhere((item) => item['id'] == id,
              orElse: () => {});
          final userId = c['user_id'] as String?;
          if (userId != null) {
            await _deleteSingleUserCascade(userId, 'customer');
          } else {
            try {
              await _supabase
                  .from('customer_addresses')
                  .delete()
                  .eq('customer_id', id);
            } catch (_) {}
            try {
              await _supabase
                  .from('delivery_orders')
                  .update({'customer_id': null}).eq('customer_id', id);
            } catch (_) {}
            try {
              await _supabase.from('customers').delete().eq('id', id);
            } catch (_) {}
          }
        } else if (userType == 'courier') {
          final c = _couriers.firstWhere((item) => item['id'] == id,
              orElse: () => {});
          final userId = c['user_id'] as String?;
          if (userId != null) {
            await _deleteSingleUserCascade(userId, 'courier');
          } else {
            try {
              await _supabase
                  .from('courier_locations')
                  .delete()
                  .eq('courier_id', id);
            } catch (_) {}
            try {
              await _supabase
                  .from('courier_warehouse')
                  .delete()
                  .eq('courier_id', id);
            } catch (_) {}
            try {
              await _supabase
                  .from('delivery_orders')
                  .update({'courier_id': null}).eq('courier_id', id);
            } catch (_) {}
            try {
              await _supabase.from('couriers').delete().eq('id', id);
            } catch (_) {}
          }
        } else if (userType == 'employee') {
          final e = _employees.firstWhere((item) => item['id'] == id,
              orElse: () => {});
          final userId = e['user_id'] as String?;
          if (userId != null) {
            await _deleteSingleUserCascade(userId, 'employee');
          } else {
            try {
              await _supabase
                  .from('employee_expenses')
                  .delete()
                  .eq('employee_id', id);
            } catch (_) {}
            try {
              await _supabase.from('employees').delete().eq('id', id);
            } catch (_) {}
          }
        }
      }

      setState(() {
        if (index == 0) _selectedAuthIds.clear();
        if (index == 1) _selectedCustomerIds.clear();
        if (index == 2) _selectedCourierIds.clear();
        if (index == 3) _selectedEmployeeIds.clear();
      });

      if (mounted)
        Navigator.of(context).pop(); // Dismiss loading overlay safely

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Успешно удалено элементов: ${idsToDelete.length}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted)
        Navigator.of(context).pop(); // Dismiss loading overlay safely
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при групповом удалении: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SELECTION HELPERS
  // ═══════════════════════════════════════════════════════════

  bool _hasAnySelected() {
    switch (_tabController.index) {
      case 0:
        return _selectedAuthIds.isNotEmpty;
      case 1:
        return _selectedCustomerIds.isNotEmpty;
      case 2:
        return _selectedCourierIds.isNotEmpty;
      case 3:
        return _selectedEmployeeIds.isNotEmpty;
      default:
        return false;
    }
  }

  int _getSelectedCount() {
    switch (_tabController.index) {
      case 0:
        return _selectedAuthIds.length;
      case 1:
        return _selectedCustomerIds.length;
      case 2:
        return _selectedCourierIds.length;
      case 3:
        return _selectedEmployeeIds.length;
      default:
        return 0;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // COURIER DIALOGS & ACTIONS
  // ═══════════════════════════════════════════════════════════

  void _showAddCourierDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final selectedTransports = <String>['bicycle'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.darkBorder)),
          title: const Text('Добавить курьера',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
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
                  decoration: const InputDecoration(
                    labelText: 'Номер телефона (например, +996700123456)',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Транспорт:',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.darkTextSecondary)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Электровелосипед'),
                      selected: selectedTransports.contains('bicycle'),
                      onSelected: (sel) => setDialogState(() {
                        sel
                            ? selectedTransports.add('bicycle')
                            : selectedTransports.remove('bicycle');
                        if (selectedTransports.isEmpty) {
                          selectedTransports.add('bicycle');
                        }
                      }),
                    ),
                    FilterChip(
                      label: const Text('Муравей'),
                      selected: selectedTransports.contains('scooter'),
                      onSelected: (sel) => setDialogState(() {
                        sel
                            ? selectedTransports.add('scooter')
                            : selectedTransports.remove('scooter');
                        if (selectedTransports.isEmpty) {
                          selectedTransports.add('bicycle');
                        }
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена',
                  style: TextStyle(color: AppColors.darkTextSecondary)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty ||
                    phoneCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Заполните все поля'),
                        backgroundColor: Colors.orange),
                  );
                  return;
                }
                Navigator.pop(ctx);
                await _createCourier(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  transportTypes: selectedTransports.toList(),
                );
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Создать'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white),
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
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.darkBorder)),
          title: Text('Склады для ${courier['name']}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 300),
            child: _warehouses.isEmpty
                ? const Center(
                    child: Text('Нет складов',
                        style: TextStyle(color: AppColors.darkTextSecondary)))
                : ListView.builder(
                    itemCount: _warehouses.length,
                    itemBuilder: (_, i) {
                      final wh = _warehouses[i];
                      final isLinked = linkedIds.contains(wh['id']);
                      return CheckboxListTile(
                        title: Text(wh['name'] ?? '—',
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(wh['address'] ?? '',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.darkTextSecondary)),
                        value: isLinked,
                        activeColor: AppColors.success,
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
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.darkBorder)),
        icon:
            const Icon(Icons.vpn_key, color: AppColors.successLight, size: 48),
        title: Text('Ключ для $name',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Передайте этот ключ курьеру для входа в приложение',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: AppColors.darkTextSecondary)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Text(
                key,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryLight,
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: key));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Ключ скопирован'),
                      duration: Duration(seconds: 1)),
                );
              },
              icon: const Icon(Icons.copy,
                  size: 16, color: AppColors.primaryLight),
              label: const Text('Скопировать',
                  style: TextStyle(color: AppColors.primaryLight)),
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
    final name = courier['name'] ?? 'Курьер';
    final initialRate = (courier['earning_rate'] as num?)?.toDouble();
    double rate = initialRate ?? _globalCourierEarningRate;
    bool useSystemDefault = initialRate == null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.darkBorder)),
          title: Text('Ставка курьера: $name',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: const Text('Системная ставка',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: Text(
                      'Использовать общую ставку ${(_globalCourierEarningRate * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 12)),
                  value: useSystemDefault,
                  activeColor: AppColors.success,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) {
                    setDialogState(() {
                      useSystemDefault = v ?? false;
                      if (useSystemDefault) {
                        rate = _globalCourierEarningRate;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                Opacity(
                  opacity: useSystemDefault ? 0.4 : 1.0,
                  child: AbsorbPointer(
                    absorbing: useSystemDefault,
                    child: Column(
                      children: [
                        Text(
                          '${(rate * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: rate,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          activeColor: AppColors.success,
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.success.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.success
                                        : Colors.grey.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text('$p%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color:
                                          isSelected ? AppColors.success : Colors.grey,
                                    )),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
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
                      const Icon(Icons.info_outline,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'При доставке 100 сом курьер получит ${(100 * rate).toStringAsFixed(0)} сом',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
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
              child: const Text('Отмена',
                  style: TextStyle(color: AppColors.darkTextSecondary)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _supabase.from('couriers').update({
                    'earning_rate': useSystemDefault ? null : rate,
                  }).eq('id', courier['id']);
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Ставка курьера $name обновлена: ${useSystemDefault ? "системная по умолчанию" : "${(rate * 100).toStringAsFixed(0)}%"}'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Ошибка: $e'),
                          backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Сохранить'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTransportDialog(Map<String, dynamic> courier) {
    final currentTypes = _getTransportTypes(courier);
    final selectedTransports = <String>[...currentTypes];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.darkBorder)),
          title: Text('Транспорт: ${courier['name'] ?? 'Курьер'}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Выберите доступные виды транспорта:',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.darkTextSecondary)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Электровелосипед'),
                      selected: selectedTransports.contains('bicycle'),
                      onSelected: (sel) => setDialogState(() {
                        sel
                            ? selectedTransports.add('bicycle')
                            : selectedTransports.remove('bicycle');
                        if (selectedTransports.isEmpty) {
                          selectedTransports.add('bicycle');
                        }
                      }),
                    ),
                    FilterChip(
                      label: const Text('Муравей'),
                      selected: selectedTransports.contains('scooter'),
                      onSelected: (sel) => setDialogState(() {
                        sel
                            ? selectedTransports.add('scooter')
                            : selectedTransports.remove('scooter');
                        if (selectedTransports.isEmpty) {
                          selectedTransports.add('bicycle');
                        }
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена',
                  style: TextStyle(color: AppColors.darkTextSecondary)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _updateCourierTransportTypes(
                    courier['id'], selectedTransports.toList());
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Сохранить'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createCourier({
    required String name,
    required String phone,
    required List<String> transportTypes,
  }) async {
    final key = _generateAccessKey();
    try {
      await _supabase.from('couriers').insert({
        'name': name,
        'phone': phone,
        'access_key': key,
        'transport_type':
            transportTypes.isNotEmpty ? transportTypes.first : 'bicycle',
        'transport_types': transportTypes,
        'courier_type': 'store',
        'is_active': true,
        'is_online': false,
      });

      _showKeyDialog(name, key);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _updateCourierTransportTypes(
      String courierId, List<String> transportTypes) async {
    try {
      await _supabase.from('couriers').update({
        'transport_type':
            transportTypes.isNotEmpty ? transportTypes.first : 'bicycle',
        'transport_types': transportTypes,
      }).eq('id', courierId);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка: $e'), backgroundColor: AppColors.error),
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
          SnackBar(
              content: Text('Ошибка: $e'), backgroundColor: AppColors.error),
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
          SnackBar(
              content: Text('Ошибка: $e'), backgroundColor: AppColors.error),
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

      await _supabase.from('couriers').update({
        'courier_type': 'store',
      }).eq('id', courierId);
    } catch (e) {
      debugPrint('Link error: $e');
    }
  }

  Future<void> _unlinkWarehouse(String courierId, String warehouseId) async {
    try {
      await _supabase
          .from('courier_warehouse')
          .update({
            'is_active': false,
            'left_at': DateTime.now().toIso8601String(),
          })
          .eq('courier_id', courierId)
          .eq('warehouse_id', warehouseId);

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
  // EMPLOYEE DIALOGS & ACTIONS
  // ═══════════════════════════════════════════════════════════

  void _showAddEmployeeDialog() {
    if (_warehouses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Сначала создайте хотя бы один склад'),
            backgroundColor: AppColors.warning),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final innCtrl = TextEditingController();
    final passportNumCtrl = TextEditingController();
    final passportIssuedByCtrl = TextEditingController();
    final passportIssuedDateCtrl = TextEditingController();
    final salaryAmountCtrl = TextEditingController(text: '0');

    Map<String, dynamic>? selectedWarehouse = _warehouses.first;
    String? selectedCompanyId = selectedWarehouse['organization_id'] as String?;

    List<Map<String, dynamic>> companyRoles =
        _roles.where((r) => r['company_id'] == selectedCompanyId).toList();
    Map<String, dynamic>? selectedRole =
        companyRoles.isNotEmpty ? companyRoles.first : null;

    String? selectedSalaryType = 'monthly';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          companyRoles = _roles
              .where((r) => r['company_id'] == selectedCompanyId)
              .toList();
          if (selectedRole != null && !companyRoles.contains(selectedRole)) {
            selectedRole = companyRoles.isNotEmpty ? companyRoles.first : null;
          } else if (selectedRole == null && companyRoles.isNotEmpty) {
            selectedRole = companyRoles.first;
          }

          return AlertDialog(
            backgroundColor: AppColors.darkSurface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.darkBorder)),
            title: const Text('Добавить сотрудника склада',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 500,
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Имя сотрудника *',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(
                          labelText:
                              'Номер телефона (например, +996700123456) *',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        initialValue: selectedWarehouse,
                        dropdownColor: AppColors.darkSurface,
                        decoration: const InputDecoration(
                          labelText: 'Склад привязки *',
                          prefixIcon: Icon(Icons.store_rounded),
                        ),
                        items: _warehouses.map((wh) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: wh,
                            child: Text(wh['name'] ?? '—',
                                style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedWarehouse = val;
                            selectedCompanyId =
                                val?['organization_id'] as String?;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        initialValue: selectedRole,
                        dropdownColor: AppColors.darkSurface,
                        decoration: const InputDecoration(
                          labelText: 'Роль *',
                          prefixIcon: Icon(Icons.badge_rounded),
                        ),
                        items: companyRoles.map((role) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: role,
                            child: Text(role['name'] ?? '—',
                                style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedRole = val;
                          });
                        },
                      ),
                      if (companyRoles.isEmpty) ...[
                        const SizedBox(height: 4),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Внимание: У этой компании нет созданных ролей. Сначала добавьте роли.',
                            style: TextStyle(
                                color: AppColors.warningLight, fontSize: 11),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: pinCtrl,
                        decoration: const InputDecoration(
                          labelText:
                              'Логин-код (PIN) для входа (например, 1234) *',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.darkBorder),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Дополнительные сведения (необязательно)',
                            style: TextStyle(
                                color: AppColors.darkTextSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: innCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ИНН сотрудника',
                          prefixIcon: Icon(Icons.fingerprint_rounded),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passportNumCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Серия/номер паспорта',
                          prefixIcon: Icon(Icons.assignment_ind_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passportIssuedByCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Паспорт выдан (орган)',
                          prefixIcon: Icon(Icons.domain_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passportIssuedDateCtrl,
                        decoration: const InputDecoration(
                          hintText: 'ДД.ММ.ГГГГ',
                          labelText: 'Паспорт выдан (дата)',
                          prefixIcon: Icon(Icons.calendar_today_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSalaryType,
                        dropdownColor: AppColors.darkSurface,
                        decoration: const InputDecoration(
                          labelText: 'Тип начисления зарплаты',
                          prefixIcon: Icon(Icons.payments_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'monthly',
                              child: Text('Месячный оклад',
                                  style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(
                              value: 'hourly',
                              child: Text('Почасовая ставка',
                                  style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(
                              value: 'daily',
                              child: Text('Дневная ставка',
                                  style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(
                              value: 'weekly',
                              child: Text('Недельная ставка',
                                  style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(
                              value: 'percent_sales',
                              child: Text('% от продаж',
                                  style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(
                              value: 'percent_services',
                              child: Text('% от услуг',
                                  style: TextStyle(color: Colors.white))),
                        ],
                        onChanged: (val) =>
                            setDialogState(() => selectedSalaryType = val),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: salaryAmountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Сумма оклада / процентная ставка',
                          prefixIcon: Icon(Icons.monetization_on_rounded),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена',
                    style: TextStyle(color: AppColors.darkTextSecondary)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final phone = phoneCtrl.text.trim();
                  final pin = pinCtrl.text.trim();

                  if (name.isEmpty || phone.isEmpty || pin.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Заполните обязательные поля (*)'),
                          backgroundColor: AppColors.warning),
                    );
                    return;
                  }

                  if (selectedWarehouse == null || selectedCompanyId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Выберите склад'),
                          backgroundColor: AppColors.warning),
                    );
                    return;
                  }

                  if (selectedRole == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Выберите роль (компания должна иметь роли)'),
                          backgroundColor: AppColors.warning),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  await _createEmployee(
                    name: name,
                    phone: phone,
                    pin: pin,
                    roleId: selectedRole!['id'] as String,
                    warehouseId: selectedWarehouse!['id'] as String,
                    companyId: selectedCompanyId!,
                    inn: innCtrl.text.trim().isEmpty
                        ? null
                        : innCtrl.text.trim(),
                    passportNumber: passportNumCtrl.text.trim().isEmpty
                        ? null
                        : passportNumCtrl.text.trim(),
                    passportIssuedBy: passportIssuedByCtrl.text.trim().isEmpty
                        ? null
                        : passportIssuedByCtrl.text.trim(),
                    passportIssuedDate:
                        passportIssuedDateCtrl.text.trim().isEmpty
                            ? null
                            : passportIssuedDateCtrl.text.trim(),
                    salaryType: selectedSalaryType ?? 'monthly',
                    salaryAmount:
                        double.tryParse(salaryAmountCtrl.text.trim()) ?? 0.0,
                  );
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Создать'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createEmployee({
    required String name,
    required String phone,
    required String pin,
    required String roleId,
    required String warehouseId,
    required String companyId,
    String? inn,
    String? passportNumber,
    String? passportIssuedBy,
    String? passportIssuedDate,
    required String salaryType,
    required double salaryAmount,
  }) async {
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
                CircularProgressIndicator(color: AppColors.success),
                SizedBox(width: 20),
                Text('Создание сотрудника...',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final now = DateTime.now().toIso8601String();
      await _supabase.from('employees').insert({
        'company_id': companyId,
        'warehouse_id': warehouseId,
        'name': name,
        'phone': phone,
        'pin_code': pin,
        'role_id': roleId,
        'allowed_warehouses': [warehouseId],
        'is_active': true,
        'inn': inn,
        'passport_number': passportNumber,
        'passport_issued_by': passportIssuedBy,
        'passport_issued_date': passportIssuedDate,
        'salary_type': salaryType,
        'salary_amount': salaryAmount,
        'created_at': now,
        'updated_at': now,
      });

      if (mounted)
        Navigator.of(context).pop(); // Dismiss loading overlay safely

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Сотрудник "$name" успешно создан'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted)
        Navigator.of(context).pop(); // Dismiss loading overlay safely
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка создания сотрудника: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PASSWORD MANAGEMENT ACTIONS
  // ═══════════════════════════════════════════════════════════

  void _showChangePasswordDialog(String userId, String userIdentifier) {
    final passwordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.darkBorder)),
        title: const Text('Сменить пароль',
            style: TextStyle(
                color: AppColors.darkTextPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Изменение пароля для пользователя:',
                style: TextStyle(
                    color: AppColors.darkTextSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text(userIdentifier,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Новый пароль',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена',
                style: TextStyle(color: AppColors.darkTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newPassword = passwordCtrl.text.trim();
              if (newPassword.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Пароль должен быть не менее 6 символов'),
                      backgroundColor: AppColors.warning),
                );
                return;
              }
              Navigator.pop(ctx);
              await _changeUserPassword(userId, newPassword, userIdentifier);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeUserPassword(
      String userId, String newPassword, String userIdentifier) async {
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
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(width: 20),
                Text('Обновление пароля...',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await _supabase.auth.admin.updateUserById(
        userId,
        attributes: AdminUserAttributes(
          password: newPassword,
        ),
      );

      if (mounted)
        Navigator.of(context).pop(); // Dismiss loading overlay safely

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Пароль для пользователя $userIdentifier успешно изменен'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        Navigator.of(context).pop(); // Dismiss loading overlay safely
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка смены пароля: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // GENERAL HELPERS
  // ═══════════════════════════════════════════════════════════

  List<String> _getTransportTypes(Map<String, dynamic> courier) {
    final types = courier['transport_types'];
    if (types is List && types.isNotEmpty) {
      return types.map((t) => t.toString()).where((t) => t.isNotEmpty).toList();
    }
    final legacy = courier['transport_type'];
    if (legacy != null && legacy.toString().isNotEmpty) {
      return [legacy.toString()];
    }
    return [];
  }

  String _generateAccessKey() {
    final rng = Random.secure();
    return List.generate(6, (_) => rng.nextInt(10)).join();
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'Активен' : 'Отключен',
        style: TextStyle(
          color: isActive ? AppColors.successLight : AppColors.errorLight,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _translateRole(String? role) {
    if (role == null) return '—';
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Администратор';
      case 'operator':
        return 'Оператор';
      case 'picker':
        return 'Сборщик';
      case 'courier':
        return 'Курьер';
      default:
        return role;
    }
  }

  String _getEmployeeWarehouseNames(Map<String, dynamic> e) {
    final rawWh = e['allowed_warehouses'];
    List<String> ids = [];
    if (rawWh is List) {
      ids = rawWh.map((item) => item.toString()).toList();
    } else if (rawWh is String && rawWh.isNotEmpty) {
      ids = rawWh
          .replaceAll('{', '')
          .replaceAll('}', '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (ids.isEmpty) {
      // Fallback to single warehouse_id if exists
      final singleId = e['warehouse_id'];
      if (singleId != null) {
        ids.add(singleId.toString());
      }
    }

    final names = ids
        .map((id) {
          final wh = _warehouses.firstWhere((w) => w['id'] == id,
              orElse: () => <String, dynamic>{});
          return wh['name'] ?? '—';
        })
        .where((name) => name != '—')
        .toList();

    return names.isEmpty ? '—' : names.join(', ');
  }
}
