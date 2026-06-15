import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:intl/intl.dart';
import '../../widgets/admin_page_body.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  
  bool _loading = true;
  String _searchQuery = '';
  
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _couriers = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _authUsers = [];
  String? _authError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update action buttons based on active tab
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
      // 1. Fetch Customers
      final customersData = await _supabase
          .from('customers')
          .select('*, user_profiles(*)')
          .order('created_at', ascending: false);
      
      // 2. Fetch Couriers
      final couriersData = await _supabase
          .from('couriers')
          .select('*, user_profiles(*)')
          .order('created_at', ascending: false);

      // 3. Fetch Employees
      final employeesData = await _supabase
          .from('employees')
          .select('*, user_profiles(*), warehouses(name)')
          .order('created_at', ascending: false);

      // 4. Fetch Auth Users (requires service_role permissions)
      List<Map<String, dynamic>> authList = [];
      try {
        final users = await _supabase.auth.admin.listUsers();
        authList = users.map((u) => {
          'id': u.id,
          'email': u.email ?? '',
          'phone': u.phone ?? '',
          'created_at': u.createdAt,
          'last_sign_in': u.lastSignInAt ?? '',
          'role': u.role ?? '',
        }).toList();
      } catch (e) {
        _authError = 'Нет доступа к Auth Admin API (требуется service_role)';
        debugPrint('Auth Admin API error: $e');
      }

      setState(() {
        _customers = List<Map<String, dynamic>>.from(customersData);
        _couriers = List<Map<String, dynamic>>.from(couriersData);
        _employees = List<Map<String, dynamic>>.from(employeesData);
        _authUsers = authList;
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

  // Filtered lists based on search query
  List<Map<String, dynamic>> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers.where((c) {
      final name = (c['name'] ?? c['user_profiles']?['name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? c['user_profiles']?['phone'] ?? '').toString().toLowerCase();
      final email = (c['user_profiles']?['email'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || phone.contains(_searchQuery) || email.contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredCouriers {
    if (_searchQuery.isEmpty) return _couriers;
    return _couriers.where((c) {
      final name = (c['name'] ?? c['user_profiles']?['name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? c['user_profiles']?['phone'] ?? '').toString().toLowerCase();
      final email = (c['user_profiles']?['email'] ?? '').toString().toLowerCase();
      final key = (c['access_key'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || phone.contains(_searchQuery) || email.contains(_searchQuery) || key.contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    if (_searchQuery.isEmpty) return _employees;
    return _employees.where((e) {
      final name = (e['user_profiles']?['name'] ?? '').toString().toLowerCase();
      final phone = (e['user_profiles']?['phone'] ?? '').toString().toLowerCase();
      final email = (e['user_profiles']?['email'] ?? '').toString().toLowerCase();
      final role = (e['role'] ?? '').toString().toLowerCase();
      final wh = (e['warehouses']?['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || phone.contains(_searchQuery) || email.contains(_searchQuery) || role.contains(_searchQuery) || wh.contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredAuthUsers {
    if (_searchQuery.isEmpty) return _authUsers;
    return _authUsers.where((u) {
      final email = (u['email'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString().toLowerCase();
      final id = (u['id'] ?? '').toString().toLowerCase();
      return email.contains(_searchQuery) || phone.contains(_searchQuery) || id.contains(_searchQuery);
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
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 16),
                IconButton(
                  tooltip: 'Обновить данные',
                  onPressed: _loadData,
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
          const SizedBox(height: 16),

          // Tab Bar navigation
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.darkBorder, width: 1)),
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
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
        itemBuilder: (context, idx) => _buildAuthUserMobileCard(_filteredAuthUsers[idx]),
      );
    }

    return _buildDesktopTable(
      columns: const ['ID', 'Email', 'Телефон', 'Создан', 'Последний вход', 'Действия'],
      rows: _filteredAuthUsers.map((u) {
        return DataRow(
          cells: [
            DataCell(
              SelectableText(
                u['id'] ?? '—',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.darkTextSecondary),
              ),
            ),
            DataCell(Text(u['email']?.isEmpty == true ? '—' : u['email'], style: const TextStyle(color: Colors.white))),
            DataCell(Text(u['phone']?.isEmpty == true ? '—' : u['phone'], style: const TextStyle(color: Colors.white))),
            DataCell(Text(_formatDate(u['created_at']), style: const TextStyle(color: AppColors.darkTextSecondary))),
            DataCell(Text(_formatDate(u['last_sign_in']), style: const TextStyle(color: AppColors.darkTextSecondary))),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 20),
                    onPressed: () => _showAuthUserDetail(u),
                    tooltip: 'Детали',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever_rounded, color: AppColors.errorLight, size: 20),
                    onPressed: () => _confirmDeleteUser(u['id'], 'auth', u['email'] ?? u['phone'] ?? 'Без контактов'),
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
        itemBuilder: (context, idx) => _buildCustomerMobileCard(_filteredCustomers[idx]),
      );
    }

    return _buildDesktopTable(
      columns: const ['Имя', 'Телефон', 'Email', 'Зарегистрирован', 'Действия'],
      rows: _filteredCustomers.map((c) {
        final profile = c['user_profiles'] ?? {};
        final name = c['name'] ?? profile['name'] ?? '—';
        final phone = c['phone'] ?? profile['phone'] ?? '—';
        final email = profile['email'] ?? '—';
        
        return DataRow(
          cells: [
            DataCell(Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
            DataCell(Text(phone, style: const TextStyle(color: Colors.white))),
            DataCell(Text(email, style: const TextStyle(color: Colors.white))),
            DataCell(Text(_formatDate(c['created_at']), style: const TextStyle(color: AppColors.darkTextSecondary))),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 20),
                    onPressed: () => _showCustomerDetail(c),
                    tooltip: 'Детали',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever_rounded, color: AppColors.errorLight, size: 20),
                    onPressed: () => _confirmDeleteUser(c['user_id'], 'customer', name),
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
        itemBuilder: (context, idx) => _buildCourierMobileCard(_filteredCouriers[idx]),
      );
    }

    return _buildDesktopTable(
      columns: const ['Имя', 'Телефон', 'Ключ', 'Ставка', 'Статус', 'Действия'],
      rows: _filteredCouriers.map((c) {
        final profile = c['user_profiles'] ?? {};
        final name = c['name'] ?? profile['name'] ?? '—';
        final phone = c['phone'] ?? profile['phone'] ?? '—';
        final key = c['access_key'] ?? '—';
        final rate = '${((c['earning_rate'] as num?)?.toDouble() ?? 0.90) * 100 ~/ 1}%';
        final isActive = c['is_active'] == true;

        return DataRow(
          cells: [
            DataCell(Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
            DataCell(Text(phone, style: const TextStyle(color: Colors.white))),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(key, style: const TextStyle(fontFamily: 'monospace', color: AppColors.primaryLight, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
            DataCell(Text(rate, style: const TextStyle(color: AppColors.successLight, fontWeight: FontWeight.bold))),
            DataCell(_buildStatusBadge(isActive)),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 20),
                    onPressed: () => _showCourierDetail(c),
                    tooltip: 'Детали',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever_rounded, color: AppColors.errorLight, size: 20),
                    onPressed: () => _confirmDeleteUser(c['user_id'], 'courier', name),
                    tooltip: 'Удалить курьера',
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
        itemBuilder: (context, idx) => _buildEmployeeMobileCard(_filteredEmployees[idx]),
      );
    }

    return _buildDesktopTable(
      columns: const ['Имя', 'Телефон', 'Роль', 'Склад', 'Действия'],
      rows: _filteredEmployees.map((e) {
        final profile = e['user_profiles'] ?? {};
        final name = profile['name'] ?? '—';
        final phone = profile['phone'] ?? '—';
        final role = _translateRole(e['role']);
        final wh = e['warehouses']?['name'] ?? '—';

        return DataRow(
          cells: [
            DataCell(Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
            DataCell(Text(phone, style: const TextStyle(color: Colors.white))),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(role, style: const TextStyle(color: AppColors.infoLight, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
            DataCell(Text(wh, style: const TextStyle(color: Colors.white))),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 20),
                    onPressed: () => _showEmployeeDetail(e),
                    tooltip: 'Детали',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever_rounded, color: AppColors.errorLight, size: 20),
                    onPressed: () => _confirmDeleteUser(e['user_id'], 'employee', name),
                    tooltip: 'Удалить сотрудника',
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDesktopTable({required List<String> columns, required List<DataRow> rows}) {
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
            columnSpacing: 30,
            columns: columns.map((col) => DataColumn(
              label: Text(
                col,
                style: const TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            )).toList(),
            rows: rows,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'Активен' : 'Отключен',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isActive ? AppColors.successLight : AppColors.errorLight,
        ),
      ),
    );
  }

  String _translateRole(String? role) {
    if (role == null) return 'Сотрудник';
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Администратор';
      case 'manager':
        return 'Менеджер';
      case 'worker':
        return 'Работник склада';
      default:
        return role;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // MOBILE CARDS
  // ═══════════════════════════════════════════════════════════

  Widget _buildAuthUserMobileCard(Map<String, dynamic> u) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  u['email']?.isEmpty == true ? u['phone'] : u['email'],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 20),
                    onPressed: () => _showAuthUserDetail(u),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.delete_forever_rounded, color: AppColors.errorLight, size: 20),
                    onPressed: () => _confirmDeleteUser(u['id'], 'auth', u['email'] ?? u['phone'] ?? 'Без контактов'),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('ID: ${u['id']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.darkTextTertiary)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Создан: ${_formatDate(u['created_at'])}', style: const TextStyle(fontSize: 11, color: AppColors.darkTextSecondary)),
              if (u['last_sign_in'] != null)
                Text('Вход: ${_formatDate(u['last_sign_in'])}', style: const TextStyle(fontSize: 11, color: AppColors.darkTextSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerMobileCard(Map<String, dynamic> c) {
    final profile = c['user_profiles'] ?? {};
    final name = c['name'] ?? profile['name'] ?? '—';
    final phone = c['phone'] ?? profile['phone'] ?? '—';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(phone, style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Дата: ${_formatDate(c['created_at'])}', style: const TextStyle(color: AppColors.darkTextTertiary, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 20),
            onPressed: () => _showCustomerDetail(c),
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded, color: AppColors.errorLight, size: 20),
            onPressed: () => _confirmDeleteUser(c['user_id'], 'customer', name),
          ),
        ],
      ),
    );
  }

  Widget _buildCourierMobileCard(Map<String, dynamic> c) {
    final profile = c['user_profiles'] ?? {};
    final name = c['name'] ?? profile['name'] ?? '—';
    final phone = c['phone'] ?? profile['phone'] ?? '—';
    final key = c['access_key'] ?? '—';
    final rate = '${((c['earning_rate'] as num?)?.toDouble() ?? 0.90) * 100 ~/ 1}%';
    final isActive = c['is_active'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              _buildStatusBadge(isActive),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(phone, style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 13)),
              const Spacer(),
              Text('Ставка: $rate', style: const TextStyle(color: AppColors.successLight, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Ключ: $key', style: const TextStyle(fontFamily: 'monospace', color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 18),
                onPressed: () => _showCourierDetail(c),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 14),
              IconButton(
                icon: const Icon(Icons.delete_forever_rounded, color: AppColors.errorLight, size: 18),
                onPressed: () => _confirmDeleteUser(c['user_id'], 'courier', name),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeMobileCard(Map<String, dynamic> e) {
    final profile = e['user_profiles'] ?? {};
    final name = profile['name'] ?? '—';
    final phone = profile['phone'] ?? '—';
    final role = _translateRole(e['role']);
    final wh = e['warehouses']?['name'] ?? '—';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(role, style: const TextStyle(color: AppColors.infoLight, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(phone, style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Склад: $wh', style: const TextStyle(color: AppColors.darkTextTertiary, fontSize: 12), overflow: TextOverflow.ellipsis),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 18),
                    onPressed: () => _showEmployeeDetail(e),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 14),
                  IconButton(
                    icon: const Icon(Icons.delete_forever_rounded, color: AppColors.errorLight, size: 18),
                    onPressed: () => _confirmDeleteUser(e['user_id'], 'employee', name),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
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
    final profile = c['user_profiles'] ?? {};
    _showDetailDialog(
      title: 'Профиль клиента AkJol Go',
      details: {
        'ID записи клиента': c['id'] ?? '—',
        'ID пользователя (Auth)': c['user_id'] ?? '—',
        'Имя': c['name'] ?? profile['name'] ?? '—',
        'Номер телефона': c['phone'] ?? profile['phone'] ?? '—',
        'Электронная почта': profile['email'] ?? '—',
        'Дата создания профиля': _formatDate(c['created_at']),
      },
    );
  }

  void _showCourierDetail(Map<String, dynamic> c) {
    final profile = c['user_profiles'] ?? {};
    final transports = (c['transport_types'] as List?)?.join(', ') ?? 'Велосипед';
    _showDetailDialog(
      title: 'Профиль курьера AkJol Pro',
      details: {
        'ID курьера': c['id'] ?? '—',
        'ID пользователя (Auth)': c['user_id'] ?? '—',
        'Имя курьера': c['name'] ?? profile['name'] ?? '—',
        'Номер телефона': c['phone'] ?? profile['phone'] ?? '—',
        'Код доступа (ключ)': c['access_key'] ?? '—',
        'Процент заработка (ставка)': '${((c['earning_rate'] as num?)?.toDouble() ?? 0.90) * 100}%',
        'Типы транспорта': transports,
        'Статус активности': c['is_active'] == true ? 'Активен' : 'Отключен',
        'В сети (Online)': c['is_online'] == true ? 'Да' : 'Нет',
        'Зарегистрирован': _formatDate(c['created_at']),
      },
    );
  }

  void _showEmployeeDetail(Map<String, dynamic> e) {
    final profile = e['user_profiles'] ?? {};
    _showDetailDialog(
      title: 'Сотрудник TakEsep Warehouse',
      details: {
        'ID сотрудника': e['id'] ?? '—',
        'ID пользователя (Auth)': e['user_id'] ?? '—',
        'Имя сотрудника': profile['name'] ?? '—',
        'Номер телефона': profile['phone'] ?? '—',
        'Электронная почта': profile['email'] ?? '—',
        'Роль на складе': _translateRole(e['role']),
        'Склад привязки': e['warehouses']?['name'] ?? '—',
        'Дата привязки': _formatDate(e['created_at']),
      },
    );
  }

  void _showDetailDialog({required String title, required Map<String, String> details}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.darkBorder)),
        title: Text(title, style: const TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.bold)),
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
                        Text(entry.key, style: const TextStyle(color: AppColors.darkTextTertiary, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        SelectableText(
                          entry.value,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: entry.key.contains('ID') || entry.key.contains('ключ') ? 'monospace' : null,
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
            child: const Text('Закрыть', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CASCADE DELETE WORKFLOW
  // ═══════════════════════════════════════════════════════════

  Future<void> _confirmDeleteUser(String? userId, String userType, String userName) async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось определить ID пользователя'), backgroundColor: AppColors.error),
      );
      return;
    }

    // Double confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.darkBorder)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.errorLight),
            const SizedBox(width: 10),
            const Text('Удаление аккаунта', style: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Вы действительно хотите удалить пользователя "$userName"?', style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            Text(
              'Это действие каскадно удалит профиль, сессии, FCM-токены, корзину, привязки курьера/склада и учетные данные для авторизации в Supabase Auth.',
              style: TextStyle(color: AppColors.errorLight.withValues(alpha: 0.85), fontSize: 13),
            ),
            const SizedBox(height: 10),
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
            child: const Text('Удалить навсегда'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show progress loading indicator overlay
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
                Text('Выполняется каскадное удаление...', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Execute the cascade deletions ( FK cleanups )
      // 1. Core user tables
      try { await _supabase.from('user_fcm_tokens').delete().eq('user_id', userId); } catch (_) {}
      try { await _supabase.from('favorites').delete().eq('user_id', userId); } catch (_) {}
      try { await _supabase.from('cart_drafts').delete().eq('user_id', userId); } catch (_) {}
      try { await _supabase.from('addresses').update({'created_by': null}).eq('created_by', userId); } catch (_) {}
      try { await _supabase.from('user_profiles').delete().eq('id', userId); } catch (_) {}

      // 2. Customers cascade
      if (userType == 'customer' || userType == 'auth') {
        final cust = await _supabase.from('customers').select('id').eq('user_id', userId).maybeSingle();
        if (cust != null) {
          final custId = cust['id'];
          final orders = await _supabase.from('delivery_orders').select('id').eq('customer_id', custId);
          for (final o in orders) {
            final oId = o['id'];
            try { await _supabase.from('delivery_order_items').delete().eq('order_id', oId); } catch (_) {}
            try { await _supabase.from('delivery_order_messages').delete().eq('order_id', oId); } catch (_) {}
            try { await _supabase.from('delivery_order_ratings').delete().eq('order_id', oId); } catch (_) {}
            try { await _supabase.from('delivery_ratings').delete().eq('order_id', oId); } catch (_) {}
            try { await _supabase.from('delivery_order_status_history').delete().eq('order_id', oId); } catch (_) {}
            try { await _supabase.from('transactions').delete().eq('order_id', oId); } catch (_) {}
          }
          try { await _supabase.from('delivery_ratings').delete().eq('customer_id', custId); } catch (_) {}
          try { await _supabase.from('delivery_order_ratings').delete().eq('customer_id', custId); } catch (_) {}
          try { await _supabase.from('delivery_orders').delete().eq('customer_id', custId); } catch (_) {}
          try { await _supabase.from('customer_addresses').delete().eq('customer_id', custId); } catch (_) {}
          try { await _supabase.from('customers').delete().eq('id', custId); } catch (_) {}
        }
      }

      // 3. Couriers cascade
      if (userType == 'courier' || userType == 'auth') {
        final cour = await _supabase.from('couriers').select('id').eq('user_id', userId).maybeSingle();
        if (cour != null) {
          final courId = cour['id'];
          try { await _supabase.from('courier_locations').delete().eq('courier_id', courId); } catch (_) {}
          try { await _supabase.from('delivery_orders').update({'courier_id': null}).eq('courier_id', courId); } catch (_) {}
          try { await _supabase.from('couriers').delete().eq('id', courId); } catch (_) {}
        }
      }

      // 4. Employees cascade
      if (userType == 'employee' || userType == 'auth') {
        final emp = await _supabase.from('employees').select('id').eq('user_id', userId).maybeSingle();
        if (emp != null) {
          final empId = emp['id'];
          try { await _supabase.from('employee_expenses').delete().eq('employee_id', empId); } catch (_) {}
          try { await _supabase.from('employees').delete().eq('id', empId); } catch (_) {}
        }
      }

      // 5. Delete user credentials from Supabase Auth
      await _supabase.auth.admin.deleteUser(userId);

      // Dismiss loading overlay
      if (mounted) Navigator.pop(context);

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
      // Dismiss loading overlay
      if (mounted) Navigator.pop(context);
      
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
}
