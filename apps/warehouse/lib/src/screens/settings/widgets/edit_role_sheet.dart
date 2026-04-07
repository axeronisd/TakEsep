import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:uuid/uuid.dart';

import '../../../data/powersync_db.dart';
import '../../../data/supabase_sync.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/employee_providers.dart';
import '../../../utils/snackbar_helper.dart';

/// BottomSheet for creating or editing a Role.
class EditRoleSheet extends ConsumerStatefulWidget {
  final Role? role;

  const EditRoleSheet({super.key, this.role});

  @override
  ConsumerState<EditRoleSheet> createState() => _EditRoleSheetState();
}

class _EditRoleSheetState extends ConsumerState<EditRoleSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _pinController;
  final Set<String> _selectedPermissions = {};
  bool _isSaving = false;

  bool get _isEditing => widget.role != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.role?.name ?? '');
    _pinController = TextEditingController(text: widget.role?.pinCode ?? '');
    if (widget.role != null) {
      _selectedPermissions.addAll(widget.role!.permissions);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role?.isSystem == true) {
      return _buildSystemRoleView(context);
    }

    final cs = Theme.of(context).colorScheme;
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 600;
    
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
            _isEditing ? 'Редактировать роль' : 'Создать новую роль',
            style: AppTypography.headlineMedium.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Настройте доступы и общий PIN-код для этой группы сотрудников',
            style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: AppSpacing.xl),
          
          // Form Content
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    autofocus: !_isEditing,
                    decoration: InputDecoration(
                      labelText: 'Название роли *',
                      hintText: 'Например: Кассир или Менеджер',
                      prefixIcon: const Icon(Icons.badge_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Общий PIN-код для роли (опционально)',
                      helperText: 'Сотрудники с этой ролью смогут входить используя этот PIN-код, если у них нет личного',
                      prefixIcon: const Icon(Icons.lock_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  Row(children: [
                    Icon(Icons.rule_rounded, size: 20, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('Права доступа', style: AppTypography.headlineSmall.copyWith(color: cs.onSurface, fontSize: 16)),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Column(
                      children: Role.allPermissions.map((perm) {
                        final label = Role.permissionLabels[perm] ?? perm;
                        return CheckboxListTile(
                          value: _selectedPermissions.contains(perm),
                          title: Text(label, style: TextStyle(color: cs.onSurface)),
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: VisualDensity.compact,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedPermissions.add(perm);
                              } else {
                                _selectedPermissions.remove(perm);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
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
              if (_isEditing) ...[
                const SizedBox(width: AppSpacing.md),
                OutlinedButton(
                  onPressed: _isSaving ? null : _deleteRole,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                ),
              ],
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: isMobile ? 1 : 0,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveRole,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_isEditing ? 'Сохранить изменения' : 'Создать роль', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemRoleView(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
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
            widget.role!.name,
            style: AppTypography.headlineMedium.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Это системная роль. Вы не можете менять её название или доступы.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.warning),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(children: [
            Icon(Icons.rule_rounded, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text('Права доступа', style: AppTypography.headlineSmall.copyWith(color: cs.onSurface, fontSize: 16)),
          ]),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.role!.permissions.map((perm) {
              final label = Role.permissionLabels[perm] ?? perm;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(label, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
            ),
            child: const Text('Закрыть', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRole() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showErrorSnackBar(context, 'Укажите название роли');
      return;
    }
    if (_selectedPermissions.isEmpty) {
      showErrorSnackBar(context, 'Выберите хотя бы одно право доступа');
      return;
    }

    setState(() => _isSaving = true);
    final companyId = ref.read(currentCompanyProvider)?.id;
    if (companyId == null) return;

    final pinCode = _pinController.text.trim();
    // Save string format for PowerSync
    final permissionsString = '{${_selectedPermissions.join(',')}}';

    try {
      if (_isEditing) {
        await powerSyncDb.execute(
          'UPDATE roles SET name = ?, pin_code = ?, permissions = ? WHERE id = ? AND company_id = ?',
          [name, pinCode, permissionsString, widget.role!.id, companyId],
        );
        await SupabaseSync.update('roles', widget.role!.id, {
          'name': name, 'pin_code': pinCode, 'permissions': permissionsString,
        });
      } else {
        final newId = const Uuid().v4();
        final now = DateTime.now().toIso8601String();
        await powerSyncDb.execute(
          'INSERT INTO roles (id, company_id, name, permissions, pin_code, is_system, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [newId, companyId, name, permissionsString, pinCode, 0, now],
        );
        await SupabaseSync.upsert('roles', {
          'id': newId, 'company_id': companyId, 'name': name,
          'permissions': permissionsString, 'pin_code': pinCode,
          'is_system': false, 'created_at': now,
        });
      }
      
      ref.invalidate(rolesListProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Ошибка сохранения: $e');
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteRole() async {
    // confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить роль?'),
        content: Text('Сотрудники с этой ролью потеряют доступ. Действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await powerSyncDb.execute('DELETE FROM roles WHERE id = ?', [widget.role!.id]);
      await SupabaseSync.delete('roles', widget.role!.id);
      ref.invalidate(rolesListProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Ошибка удаления: $e');
        setState(() => _isSaving = false);
      }
    }
  }
}
