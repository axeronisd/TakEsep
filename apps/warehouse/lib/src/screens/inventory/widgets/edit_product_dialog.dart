import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../../providers/inventory_providers.dart';
import '../../../providers/inventory_repository_provider.dart';
import '../../../data/supabase_storage_helper.dart';

/// Dialog for editing product details: name, price, barcode, description, image.
/// Changes are scoped to this warehouse only.
Future<bool?> showEditProductDialog(
  BuildContext context,
  WidgetRef ref,
  Product product,
  String currencySymbol,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditProductSheet(
      product: product,
      currencySymbol: currencySymbol,
      ref: ref,
    ),
  );
}

class _EditProductSheet extends StatefulWidget {
  final Product product;
  final String currencySymbol;
  final WidgetRef ref;

  const _EditProductSheet({
    required this.product,
    required this.currencySymbol,
    required this.ref,
  });

  @override
  State<_EditProductSheet> createState() => _EditProductSheetState();
}

class _EditProductSheetState extends State<_EditProductSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _sellingPriceCtrl;
  late final TextEditingController _costPriceCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _descriptionCtrl;
  bool _saving = false;
  String? _imageUrl; // network URL or local file path
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p.name);
    _sellingPriceCtrl =
        TextEditingController(text: p.price.toStringAsFixed(0));
    _costPriceCtrl =
        TextEditingController(text: (p.costPrice ?? 0).toStringAsFixed(0));
    _barcodeCtrl = TextEditingController(text: p.barcode ?? '');
    _descriptionCtrl = TextEditingController(text: p.description ?? '');
    _imageUrl = p.imageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _costPriceCtrl.dispose();
    _barcodeCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  /// Show bottom picker: camera or gallery
  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Выберите источник',
                  style: AppTypography.bodyLarge.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _SourceButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'Камера',
                        color: AppColors.primary,
                        onTap: () => Navigator.pop(ctx, ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _SourceButton(
                        icon: Icons.photo_library_rounded,
                        label: 'Галерея',
                        color: AppColors.success,
                        onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
                if (_imageUrl != null && _imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() => _imageUrl = null);
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.error),
                      label: Text('Удалить фото',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    try {
      // image_picker on Windows doesn't support camera natively and crashes
      if (Platform.isWindows && source == ImageSource.camera) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Камера не поддерживается на ПК (Windows)'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked != null) {
        setState(() => _imageUrl = picked.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка выбора фото: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;

    setState(() => _saving = true);

    String? finalImageUrl = _imageUrl;
    if (_imageUrl != null && !_imageUrl!.startsWith('http')) {
      try {
        finalImageUrl = await SupabaseStorageHelper.uploadImage(File(_imageUrl!));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки фото: ${e.toString().replaceAll('Exception: Supabase upload error: ', '')}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _saving = false);
        return;
      }
    }

    final updated = widget.product.copyWith(
      name: _nameCtrl.text.trim(),
      price: double.tryParse(_sellingPriceCtrl.text) ?? widget.product.price,
      costPrice:
          double.tryParse(_costPriceCtrl.text) ?? widget.product.costPrice,
      barcode: _barcodeCtrl.text.trim().isEmpty
          ? null
          : _barcodeCtrl.text.trim(),
      description: _descriptionCtrl.text.trim().isEmpty
          ? null
          : _descriptionCtrl.text.trim(),
      imageUrl: finalImageUrl,
    );

    final repo = widget.ref.read(inventoryRepositoryProvider);
    final success = await repo.updateProduct(updated);

    if (success) {
      widget.ref.invalidate(inventoryProvider);
    }

    if (mounted) {
      setState(() => _saving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('«${updated.name}» обновлён'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка сохранения'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Build image widget from local path or network URL
  Widget _buildImagePreview(ColorScheme cs) {
    Widget imageWidget;

    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      if (_imageUrl!.startsWith('http://') ||
          _imageUrl!.startsWith('https://')) {
        imageWidget = Image.network(
          _imageUrl!,
          width: double.infinity,
          height: 180,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildPlaceholder(cs),
        );
      } else {
        imageWidget = Image.file(
          File(_imageUrl!),
          width: double.infinity,
          height: 180,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildPlaceholder(cs),
        );
      }
    } else {
      imageWidget = _buildPlaceholder(cs);
    }

    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: imageWidget,
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme cs) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.2),
          width: 1.5,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_rounded,
              size: 40, color: cs.onSurface.withValues(alpha: 0.25)),
          const SizedBox(height: 8),
          Text(
            'Нажмите для добавления фото',
            style: AppTypography.bodySmall.copyWith(
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Камера или галерея',
            style: AppTypography.labelSmall.copyWith(
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.only(top: 60),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Handle bar ───
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Title ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Редактировать товар',
                    style: AppTypography.bodyLarge.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded,
                      color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
          const Divider(),

          // ─── Form fields ───
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image preview — tappable
                  _buildImagePreview(cs),
                  const SizedBox(height: AppSpacing.lg),

                  // Name
                  _buildLabel('Название'),
                  TextField(
                    controller: _nameCtrl,
                    decoration: _inputDeco('Введите название товара'),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Prices row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel(
                                'Цена продажи (${widget.currencySymbol})'),
                            TextField(
                              controller: _sellingPriceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _inputDeco('0'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel(
                                'Себестоимость (${widget.currencySymbol})'),
                            TextField(
                              controller: _costPriceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _inputDeco('0'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Barcode
                  _buildLabel('Штрихкод'),
                  TextField(
                    controller: _barcodeCtrl,
                    decoration: _inputDeco('Сканируйте или введите вручную'),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Description
                  _buildLabel('Описание'),
                  TextField(
                    controller: _descriptionCtrl,
                    maxLines: 3,
                    decoration: _inputDeco('Описание товара для приложения доставки...'),
                  ),

                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '* Изменения применяются только к этому складу',
                    style: AppTypography.labelSmall.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: const Text(
                        'Сохранить',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTypography.labelMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}

// ═══════════════════════════════════════════════════
//  SOURCE BUTTON — Camera / Gallery selection
// ═══════════════════════════════════════════════════

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
