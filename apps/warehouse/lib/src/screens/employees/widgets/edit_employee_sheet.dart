import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/employee_providers.dart';

/// BottomSheet for creating or editing an Employee.
class EditEmployeeSheet extends ConsumerStatefulWidget {
  final Employee? employee;

  const EditEmployeeSheet({super.key, this.employee});

  @override
  ConsumerState<EditEmployeeSheet> createState() => _EditEmployeeSheetState();
}

class _EditEmployeeSheetState extends ConsumerState<EditEmployeeSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _pinController;
  late final TextEditingController _phoneController;
  late final TextEditingController _innController;
  late final TextEditingController _passportNumberController;
  late final TextEditingController _passportIssuedByController;
  late final TextEditingController _passportIssuedDateController;
  late final TextEditingController _salaryAmountController;

  String? _selectedRoleId;
  List<String> _selectedWarehouses = [];
  bool _isActive = true;
  bool _allWarehouses = true;
  bool _obscurePin = true;
  SalaryType _salaryType = SalaryType.monthly;
  bool _salaryAutoDeduct = false;
  bool _isSaving = false;

  bool get _isEditing => widget.employee != null;

  /// Generates a random password like AB3K-Q7YZ
  String _generateKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < 8; i++) {
      if (i == 4) buf.write('-');
      buf.write(chars[rng.nextInt(chars.length)]);
    }
    return buf.toString();
  }

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _nameController = TextEditingController(text: e?.name ?? '');
    _pinController = TextEditingController(text: e?.pinCodeHash ?? '');
    _phoneController = TextEditingController(text: e?.phone ?? '');
    _innController = TextEditingController(text: e?.inn ?? '');
    _passportNumberController = TextEditingController(text: e?.passportNumber ?? '');
    _passportIssuedByController = TextEditingController(text: e?.passportIssuedBy ?? '');
    _passportIssuedDateController = TextEditingController(text: e?.passportIssuedDate ?? '');
    _salaryAmountController = TextEditingController(text: e != null && e.salaryAmount > 0 ? e.salaryAmount.toInt().toString() : '');

    _selectedRoleId = e?.roleId;
    _selectedWarehouses = List<String>.from(e?.allowedWarehouses ?? []);
    _isActive = e?.isActive ?? true;
    _allWarehouses = e?.allowedWarehouses == null;
    _salaryType = e?.salaryType ?? SalaryType.monthly;
    _salaryAutoDeduct = e?.salaryAutoDeduct ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _phoneController.dispose();
    _innController.dispose();
    _passportNumberController.dispose();
    _passportIssuedByController.dispose();
    _passportIssuedDateController.dispose();
    _salaryAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 600;
    
    // Auth and Data providers
    final authState = ref.watch(authProvider);
    final rolesAsync = ref.watch(rolesListProvider);
    final warehouses = authState.availableWarehouses;
    
    // Bottom padding for keyboard
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.lg,
        bottom: bottomInset > 0 ? bottomInset + AppSpacing.md : AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: cs.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          
          Text(
            _isEditing ? 'Редактировать сотрудника' : 'Новый сотрудник',
            style: AppTypography.headlineMedium.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: AppSpacing.xl),
          
          // Form Content
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(cs, 'Основные данные', Icons.person_rounded),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _nameController,
                    autofocus: !_isEditing,
                    decoration: InputDecoration(
                      labelText: 'Имя сотрудника *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Номер телефона',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Пароль для входа *',
                    style: AppTypography.labelMedium.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pinController,
                          obscureText: _obscurePin,
                          decoration: InputDecoration(
                            hintText: 'ABCD-1234',
                            helperText: 'Сотрудник будет использовать его для входа в профиль',
                            prefixIcon: const Icon(Icons.key_rounded, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePin = !_obscurePin),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () => setState(() => _pinController.text = _generateKey()),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          foregroundColor: AppColors.primary,
                        ),
                        tooltip: 'Сгенерировать пароль',
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _pinController.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Пароль скопирован'), duration: Duration(seconds: 1)),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: 'Копировать',
                        color: cs.onSurface.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  _sectionHeader(cs, 'Доступ и Роли', Icons.security_rounded),
                  const SizedBox(height: AppSpacing.md),
                  rolesAsync.when(
                    data: (roles) => DropdownButtonFormField<String?>(
                      value: _selectedRoleId,
                      decoration: InputDecoration(
                        labelText: 'Должность (Роль)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Владелец (Полный доступ к системе)'),
                        ),
                        ...roles.map((r) => DropdownMenuItem<String?>(
                              value: r.id,
                              child: Text(r.name),
                            )),
                      ],
                      onChanged: (val) => setState(() => _selectedRoleId = val),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Ошибка загрузки ролей'),
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  Text('Доступные склады', style: AppTypography.labelMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: _allWarehouses,
                          title: Text('Все склады', style: TextStyle(color: cs.onSurface, fontWeight: _allWarehouses ? FontWeight.bold : FontWeight.normal)),
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: VisualDensity.compact,
                          onChanged: (val) {
                            setState(() {
                              _allWarehouses = val ?? true;
                              if (_allWarehouses) _selectedWarehouses.clear();
                            });
                          },
                        ),
                        if (!_allWarehouses) ...[
                          Divider(height: 1, color: cs.outline.withValues(alpha: 0.3)),
                          ...warehouses.map((wh) => CheckboxListTile(
                                value: _selectedWarehouses.contains(wh.id),
                                title: Text(wh.name, style: TextStyle(color: cs.onSurface)),
                                controlAffinity: ListTileControlAffinity.leading,
                                visualDensity: VisualDensity.compact,
                                contentPadding: const EdgeInsets.only(left: AppSpacing.xl, right: AppSpacing.md),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedWarehouses.add(wh.id);
                                    } else {
                                      _selectedWarehouses.remove(wh.id);
                                    }
                                  });
                                },
                              )),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  _sectionHeader(cs, 'Зарплата', Icons.payments_rounded),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<SalaryType>(
                          value: _salaryType,
                          decoration: InputDecoration(
                            labelText: 'Схема оплаты',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                          ),
                          items: SalaryType.values.map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.label),
                          )).toList(),
                          onChanged: (val) => setState(() => _salaryType = val!),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: _salaryAmountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Ставка / %',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    value: _salaryAutoDeduct,
                    title: const Text('Автоматически начислять'),
                    subtitle: const Text('Система будет сама считать ЗП по графику', style: TextStyle(fontSize: 11)),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _salaryAutoDeduct = val),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  _sectionHeader(cs, 'Паспортные данные', Icons.badge_rounded),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _innController,
                    decoration: InputDecoration(
                      labelText: 'ИНН / ПИН',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _passportNumberController,
                    decoration: InputDecoration(
                      labelText: 'Серия и номер паспорта',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _passportIssuedByController,
                          decoration: InputDecoration(
                            labelText: 'Кем выдан',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: _passportIssuedDateController,
                          decoration: InputDecoration(
                            labelText: 'Дата выдачи',
                            hintText: 'ДД.ММ.ГГГГ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_isEditing) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _sectionHeader(cs, 'Статус профиля', Icons.power_settings_new),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      decoration: BoxDecoration(
                        color: _isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: SwitchListTile(
                        value: _isActive,
                        title: Text('Профиль активен', style: TextStyle(color: _isActive ? AppColors.success : AppColors.error, fontWeight: FontWeight.bold)),
                        subtitle: Text(_isActive ? 'Сотрудник имеет доступ к системе' : 'Доступ к системе закрыт', style: const TextStyle(fontSize: 11)),
                        activeColor: AppColors.success,
                        onChanged: (val) => setState(() => _isActive = val),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              if (isMobile)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                    ),
                    child: const Text('Отмена'),
                  ),
                )
              else
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: isMobile ? 1 : 0,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_isEditing ? 'Сохранить' : 'Создать сотрудника', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(ColorScheme cs, String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 20, color: cs.primary),
      const SizedBox(width: 8),
      Text(title, style: AppTypography.headlineSmall.copyWith(color: cs.onSurface, fontSize: 16)),
    ]);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final pinCode = _pinController.text.trim();
    if (name.isEmpty || pinCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните имя и пин-код')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final notifier = ref.read(employeeListProvider.notifier);

    // Check PIN uniqueness
    final isTaken = await notifier.isPinCodeTaken(
      pinCode,
      excludeEmployeeId: widget.employee?.id,
    );
    if (isTaken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Этот пин-код уже используется другим сотрудником')),
        );
        setState(() => _isSaving = false);
      }
      return;
    }

    final allowedWarehouses = _allWarehouses ? null : _selectedWarehouses;

    if (_isEditing) {
      await notifier.updateEmployee(
        employeeId: widget.employee!.id,
        name: name,
        pinCode: pinCode,
        roleId: _selectedRoleId,
        clearRoleId: _selectedRoleId == null,
        allowedWarehouses: allowedWarehouses,
        clearAllowedWarehouses: _allWarehouses,
        isActive: _isActive,
        // Detailed info
        phone: _phoneController.text.trim(),
        clearPhone: _phoneController.text.trim().isEmpty,
        inn: _innController.text.trim(),
        clearInn: _innController.text.trim().isEmpty,
        passportNumber: _passportNumberController.text.trim(),
        clearPassportNumber: _passportNumberController.text.trim().isEmpty,
        passportIssuedBy: _passportIssuedByController.text.trim(),
        clearPassportIssuedBy: _passportIssuedByController.text.trim().isEmpty,
        passportIssuedDate: _passportIssuedDateController.text.trim(),
        clearPassportIssuedDate: _passportIssuedDateController.text.trim().isEmpty,
        salaryType: _salaryType,
        salaryAmount: double.tryParse(_salaryAmountController.text) ?? 0,
        salaryAutoDeduct: _salaryAutoDeduct,
      );
    } else {
      await notifier.createEmployee(
        name: name,
        pinCode: pinCode,
        roleId: _selectedRoleId,
        allowedWarehouses: allowedWarehouses,
        phone: _phoneController.text.trim(),
        inn: _innController.text.trim(),
        passportNumber: _passportNumberController.text.trim(),
        passportIssuedBy: _passportIssuedByController.text.trim(),
        passportIssuedDate: _passportIssuedDateController.text.trim(),
        salaryType: _salaryType,
        salaryAmount: double.tryParse(_salaryAmountController.text) ?? 0,
        salaryAutoDeduct: _salaryAutoDeduct,
      );
    }

    if (mounted) Navigator.pop(context);
  }
}
