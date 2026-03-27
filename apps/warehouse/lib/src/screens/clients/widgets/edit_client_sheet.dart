import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:takesep_core/takesep_core.dart';
import '../../../providers/client_providers.dart';

class EditClientSheet extends ConsumerStatefulWidget {
  final Client? client;
  const EditClientSheet({super.key, this.client});

  @override
  ConsumerState<EditClientSheet> createState() => _EditClientSheetState();
}

class _EditClientSheetState extends ConsumerState<EditClientSheet> {
  late final TextEditingController _nameC;
  late final TextEditingController _phoneC;
  late final TextEditingController _emailC;
  late final TextEditingController _notesC;
  String _type = 'retail';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: widget.client?.name ?? '');
    _phoneC = TextEditingController(text: widget.client?.phone ?? '');
    _emailC = TextEditingController(text: widget.client?.email ?? '');
    _notesC = TextEditingController(text: widget.client?.notes ?? '');
    _type = widget.client?.type ?? 'retail';
  }

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    _emailC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameC.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите имя клиента')));
      return;
    }

    setState(() => _isLoading = true);

    bool success = false;
    final phone = _phoneC.text.trim().isEmpty ? null : _phoneC.text.trim();
    final email = _emailC.text.trim().isEmpty ? null : _emailC.text.trim();
    final notes = _notesC.text.trim().isEmpty ? null : _notesC.text.trim();

    final notifier = ref.read(clientListProvider.notifier);

    if (widget.client == null) {
      final c = await notifier.create(
        name: name,
        phone: phone,
        email: email,
        type: _type,
        notes: notes,
      );
      success = c != null;
    } else {
      success = await notifier.update(
        clientId: widget.client!.id,
        name: name,
        phone: phone,
        email: email,
        type: _type,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.client == null ? 'Клиент добавлен' : 'Клиент сохранен'),
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ошибка при сохранении'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEdit = widget.client != null;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.only(bottom: AppSpacing.xl),
              decoration: BoxDecoration(
                color: cs.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isEdit ? 'Редактировать клиента' : 'Новый клиент',
                  style: AppTypography.headlineMedium.copyWith(color: cs.onSurface)),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _nameC,
            decoration: const InputDecoration(
              labelText: 'Имя / Название *',
              hintText: 'Например, Иван Иванов или ТОО "Ромашка"',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneC,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Телефон',
                    hintText: '+996 555 123456',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Тип клиента', style: AppTypography.labelSmall.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: cs.outline),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _type,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'retail', child: Text('Розничный')),
                            DropdownMenuItem(value: 'wholesale', child: Text('Оптовый')),
                            DropdownMenuItem(value: 'vip', child: Text('VIP')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _type = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _emailC,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'ivan@example.com',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _notesC,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Примечание',
              hintText: 'Дополнительная информация',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _isLoading ? null : _save,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isEdit ? 'Сохранить изменения' : 'Создать клиента', style: const TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
