import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../../providers/payment_methods_provider.dart';
import '../../../providers/auth_providers.dart';
import '../../../data/supabase_storage_helper.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../widgets/cached_image_widget.dart';

class EditPaymentMethodSheet extends ConsumerStatefulWidget {
  final PaymentMethod? method;

  const EditPaymentMethodSheet({super.key, this.method});

  @override
  ConsumerState<EditPaymentMethodSheet> createState() => _EditPaymentMethodSheetState();
}

class _EditPaymentMethodSheetState extends ConsumerState<EditPaymentMethodSheet> {
  final _nameController = TextEditingController();
  bool _isActive = true;
  String? _qrImageUrl;
  bool _isLoading = false;
  File? _localImageFile;

  @override
  void initState() {
    super.initState();
    if (widget.method != null) {
      _nameController.text = widget.method!.name;
      _isActive = widget.method!.isActive;
      _qrImageUrl = widget.method!.qrImageUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null) {
        setState(() => _localImageFile = File(picked.path));
      }
    } catch (e) {
      showErrorSnackBar(context, 'Ошибка выбора фото: $e');
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showErrorSnackBar(context, 'Введите название способа оплаты');
      return;
    }

    final companyId = ref.read(authProvider).currentCompany?.id;
    if (companyId == null) return;

    setState(() => _isLoading = true);

    try {
      String? finalUrl = _qrImageUrl;

      if (_localImageFile != null) {
        finalUrl = await SupabaseStorageHelper.uploadImage(_localImageFile!);
      }

      await ref.read(paymentMethodsProvider.notifier).saveMethod(
            companyId: companyId,
            id: widget.method?.id,
            name: name,
            isActive: _isActive,
            qrImageUrl: finalUrl,
          );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      showErrorSnackBar(context, 'Ошибка сохранения: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    if (widget.method == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить?'),
        content: Text('Вы уверены, что хотите удалить «${widget.method!.name}»?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ОТМЕНА')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('УДАЛИТЬ', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(paymentMethodsProvider.notifier).deleteMethod(widget.method!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isNew = widget.method == null;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
              Text(
                isNew ? 'Добавить способ оплаты' : 'Изменить способ оплаты',
                style: AppTypography.headlineSmall.copyWith(color: cs.onSurface),
              ),
              if (!isNew)
                IconButton(
                  onPressed: _isLoading ? null : _delete,
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    autofocus: isNew,
                    decoration: const InputDecoration(
                      labelText: 'Название (Например: Mbank, Kaspi)',
                      prefixIcon: Icon(Icons.payment_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Активен'),
                      Switch(
                        value: _isActive,
                        onChanged: (val) => setState(() => _isActive = val),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text('QR КОД ДЛЯ ОПЛАТЫ',
              style: AppTypography.labelSmall.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.4),
                  letterSpacing: 1.2)),
          const SizedBox(height: AppSpacing.sm),

          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
              ),
              child: _localImageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: Image.file(_localImageFile!, fit: BoxFit.contain),
                    )
                  : (_qrImageUrl != null && _qrImageUrl!.isNotEmpty)
                      ? CachedImageWidget(
                          imageUrl: _qrImageUrl, 
                          fit: BoxFit.contain,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner_rounded,
                                size: 48,
                                color: cs.onSurface.withValues(alpha: 0.3)),
                            const SizedBox(height: AppSpacing.sm),
                            Text('Нажмите, чтобы загрузить изображение',
                                style: AppTypography.bodySmall.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.5))),
                          ],
                        ),
            ),
          ),
          if (_qrImageUrl != null || _localImageFile != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _localImageFile = null;
                    _qrImageUrl = null;
                  });
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Удалить фото'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('СОХРАНИТЬ', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
