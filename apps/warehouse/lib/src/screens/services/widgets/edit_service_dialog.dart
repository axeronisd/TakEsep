import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../../providers/service_providers.dart';
import '../../../data/supabase_storage_helper.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../widgets/cached_image_widget.dart';

/// Dialog for creating or editing service details.
Future<bool?> showEditServiceDialog(
  BuildContext context,
  WidgetRef ref,
  Service? service, // null = create new
  String currencySymbol,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditServiceSheet(
      service: service,
      currencySymbol: currencySymbol,
      ref: ref,
    ),
  );
}

class _EditServiceSheet extends StatefulWidget {
  final Service? service;
  final String currencySymbol;
  final WidgetRef ref;

  const _EditServiceSheet({
    this.service,
    required this.currencySymbol,
    required this.ref,
  });

  @override
  State<_EditServiceSheet> createState() => _EditServiceSheetState();
}

class _EditServiceSheetState extends State<_EditServiceSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _descriptionCtrl;
  bool _saving = false;
  String? _imageUrl; // network URL or local file path
  bool _clearImage = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _priceCtrl = TextEditingController(text: s != null ? s.price.toString() : '');
    _categoryCtrl = TextEditingController(text: s?.category ?? '');
    _descriptionCtrl = TextEditingController(text: s?.description ?? '');
    _imageUrl = s?.imageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _categoryCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (Platform.isWindows && source == ImageSource.camera) {
        if (!mounted) return;
        showErrorSnackBar(context, 'Камера не поддерживается на ПК (Windows)');
        return;
      }

      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked != null) {
        setState(() {
           _imageUrl = picked.path;
           _clearImage = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Ошибка выбора фото: $e');
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    if (_priceCtrl.text.trim().isEmpty) return;

    setState(() => _saving = true);

    String? finalImageUrl = _imageUrl;
    // Upload if it's a new local image
    if (_imageUrl != null && !_imageUrl!.startsWith('http')) {
      try {
        finalImageUrl = await SupabaseStorageHelper.uploadImage(File(_imageUrl!));
      } catch (e) {
        if (!mounted) return;
        showErrorSnackBar(context, 'Ошибка загрузки фото: ${e.toString().replaceAll('Exception: Supabase upload error: ', '')}');
        setState(() => _saving = false);
        return;
      }
    } else if (_clearImage) {
      finalImageUrl = null;
    }

    final price = double.tryParse(_priceCtrl.text) ?? 0.0;
    final name = _nameCtrl.text.trim();
    final category = _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim();
    final description = _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim();

    bool success;
    if (widget.service == null) {
      // Create
      final newSvc = await widget.ref.read(serviceListProvider.notifier).create(
        name: name,
        price: price,
        category: category,
        description: description,
        imageUrl: finalImageUrl,
      );
      success = newSvc != null;
    } else {
      // Update
      success = await widget.ref.read(serviceListProvider.notifier).update(
        serviceId: widget.service!.id,
        name: name,
        price: price,
        category: category,
        imageUrl: finalImageUrl,
        clearImage: _clearImage,
      );
    }

    if (mounted) {
      setState(() => _saving = false);
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        showErrorSnackBar(context, 'Ошибка сохранения');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEdit = widget.service != null;

    Widget imageWidget;
    if (_clearImage || _imageUrl == null || _imageUrl!.isEmpty) {
      imageWidget = Container(
        color: cs.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.add_photo_alternate_outlined,
              size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
        ),
      );
    } else if (_imageUrl!.startsWith('http')) {
      imageWidget = CachedImageWidget(
        imageUrl: _imageUrl!,
        fit: BoxFit.contain,
      );
    } else {
      imageWidget = Image.file(
        File(_imageUrl!),
        fit: BoxFit.contain,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + 80,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isEdit ? 'Редактировать услугу' : 'Новая услуга',
                  style: AppTypography.headlineSmall.copyWith(color: cs.onSurface)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: GestureDetector(
              onTap: () async {
                final action = await showModalBottomSheet<String>(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.camera_alt_outlined),
                          title: const Text('Сделать фото (Камера)'),
                          onTap: () => Navigator.pop(ctx, 'camera'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library_outlined),
                          title: const Text('Выбрать из Галереи'),
                          onTap: () => Navigator.pop(ctx, 'gallery'),
                        ),
                        if (_imageUrl != null && !_clearImage)
                          ListTile(
                            leading: const Icon(Icons.delete_outline, color: AppColors.error),
                            title: const Text('Удалить фото', style: TextStyle(color: AppColors.error)),
                            onTap: () => Navigator.pop(ctx, 'delete'),
                          ),
                      ],
                    ),
                  ),
                );

                if (action == 'camera') {
                  _pickImage(ImageSource.camera);
                } else if (action == 'gallery') {
                  _pickImage(ImageSource.gallery);
                } else if (action == 'delete') {
                  setState(() {
                    _clearImage = true;
                    _imageUrl = null;
                  });
                }
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: imageWidget,
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Название услуги *'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Цена * (${widget.currencySymbol})'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _categoryCtrl,
            decoration: const InputDecoration(labelText: 'Категория'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _descriptionCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Описание'),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              const SizedBox(width: AppSpacing.md),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Сохранить'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
