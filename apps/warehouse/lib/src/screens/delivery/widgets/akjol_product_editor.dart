import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

import '../../../data/powersync_db.dart';
import '../../../data/supabase_sync.dart';
import '../../../data/supabase_storage_helper.dart';
import '../../../utils/snackbar_helper.dart';

/// Полноэкранный редактор товара для каталога AkJol
class AkjolProductEditorDialog extends ConsumerStatefulWidget {
  final Product product;
  const AkjolProductEditorDialog({super.key, required this.product});

  @override
  ConsumerState<AkjolProductEditorDialog> createState() => _AkjolProductEditorDialogState();
}

class _AkjolProductEditorDialogState extends ConsumerState<AkjolProductEditorDialog> {
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;
  late bool _isPublic;

  String? _mainImageUrl;
  List<Map<String, dynamic>> _extraImages = [];
  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(
        text: widget.product.b2cDescription ?? widget.product.description ?? '');
    _priceCtrl = TextEditingController(
        text: (widget.product.b2cPrice ?? widget.product.price).toStringAsFixed(0));
    _isPublic = widget.product.isPublic;
    _mainImageUrl = widget.product.imageUrl;
    _loadExtraImages();
  }

  Future<void> _loadExtraImages() async {
    try {
      final rows = await powerSyncDb.getAll(
        'SELECT id, image_url, sort_order FROM product_images WHERE product_id = ? ORDER BY sort_order',
        [widget.product.id],
      );
      setState(() => _extraImages = rows.map((r) => Map<String, dynamic>.from(r)).toList());
    } catch (e) {
      debugPrint('Load extra images: $e');
    }
  }

  Future<void> _pickAndUploadImage({bool isMain = false}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final url = await SupabaseStorageHelper.uploadImage(File(picked.path));

      if (isMain) {
        setState(() => _mainImageUrl = url);
        final now = DateTime.now().toIso8601String();
        await powerSyncDb.execute(
          'UPDATE products SET image_url = ?, updated_at = ? WHERE id = ?',
          [url, now, widget.product.id],
        );
        await SupabaseSync.update('products', widget.product.id, {
          'image_url': url, 'updated_at': now,
        });
      } else {
        final now = DateTime.now().toIso8601String();
        final sortOrder = _extraImages.length;
        await powerSyncDb.execute(
          'INSERT INTO product_images (id, product_id, image_url, sort_order, created_at) VALUES (uuid(), ?, ?, ?, ?)',
          [widget.product.id, url, sortOrder, now],
        );
        await _loadExtraImages();
      }
      if (mounted) showInfoSnackBar(context, null, 'Фото загружено');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Ошибка загрузки: $e');
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _deleteExtraImage(String imageId) async {
    try {
      await powerSyncDb.execute('DELETE FROM product_images WHERE id = ?', [imageId]);
      await SupabaseSync.delete('product_images', imageId);
      await _loadExtraImages();
      if (mounted) showInfoSnackBar(context, null, 'Фото удалено');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Ошибка удаления: $e');
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final now = DateTime.now().toIso8601String();
      final b2cDesc = _descCtrl.text.trim();

      await powerSyncDb.execute(
        'UPDATE products SET b2c_description = ?, is_public = ?, image_url = ?, updated_at = ? WHERE id = ?',
        [b2cDesc.isEmpty ? null : b2cDesc, _isPublic ? 1 : 0, _mainImageUrl, now, widget.product.id],
      );

      await SupabaseSync.update('products', widget.product.id, {
        'b2c_description': b2cDesc.isEmpty ? null : b2cDesc,
        'is_public': _isPublic,
        'image_url': _mainImageUrl, 'updated_at': now,
      });

      if (mounted) {
        showInfoSnackBar(context, null, 'Сохранено');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Ошибка: $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = widget.product;
    final b2cPrice = double.tryParse(_priceCtrl.text) ?? p.price;
    final allPhotos = <String>[
      if (_mainImageUrl != null && _mainImageUrl!.isNotEmpty) _mainImageUrl!,
      ..._extraImages.map((img) => img['image_url'] as String),
    ];

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text('Редактирование для AkJol',
            style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(_saving ? '...' : 'Сохранить'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Название + тогл ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_rounded, color: cs.onSurface.withValues(alpha: 0.4), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                        Text('SKU: ${p.sku ?? "—"} · ${p.barcode ?? "—"}',
                            style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.4))),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                    activeTrackColor: const Color(0xFF2ECC71),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── ФОТО ──
            _label('Фотографии', required: true),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _photoTile(imageUrl: _mainImageUrl, label: 'Главное',
                      onTap: () => _pickAndUploadImage(isMain: true)),
                  ..._extraImages.map((img) => _photoTile(
                      imageUrl: img['image_url'] as String?,
                      onDelete: () => _deleteExtraImage(img['id'] as String))),
                  _photoTile(isAdd: true, onTap: () => _pickAndUploadImage(isMain: false)),
                ],
              ),
            ),
            if (_uploading)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(color: Color(0xFF2ECC71)),
              ),
            const SizedBox(height: 24),

            // ── Описание ──
            _label('Описание для AkJol'),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Опишите товар для покупателей...',
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),

            // ── Цена (только для чтения) ──
            _label('Цена товара'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
                  const SizedBox(width: 10),
                  Text(
                    '${p.price.toStringAsFixed(0)} сом',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2ECC71),
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'из базы товаров',
                    style: AppTypography.bodySmall.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── ПРЕВЬЮ ──
            _label('Превью в AkJol'),
            const SizedBox(height: 12),
            _previewCard(cs, b2cPrice, allPhotos),
          ],
        ),
      ),
    );
  }

  Widget _label(String title, {bool required = false}) {
    return Row(
      children: [
        Text(title, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
        if (required) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
            child: const Text('обязательно',
                style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }

  Widget _photoTile(
      {String? imageUrl, String? label, bool isAdd = false, VoidCallback? onTap, VoidCallback? onDelete}) {
    final cs = Theme.of(context).colorScheme;
    final hasImg = imageUrl != null && imageUrl.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            Container(
              width: 90,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isAdd
                      ? const Color(0xFF2ECC71).withValues(alpha: 0.4)
                      : hasImg
                          ? const Color(0xFF2ECC71).withValues(alpha: 0.3)
                          : cs.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: isAdd
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_photo_alternate_outlined, color: const Color(0xFF2ECC71), size: 28),
                      const SizedBox(height: 4),
                      Text('Добавить', style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.5))),
                    ])
                  : hasImg
                      ? Image.network(imageUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _empty(cs))
                      : _empty(cs),
            ),
            if (label != null)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
                  ),
                  child: Text(label, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            if (onDelete != null)
              Positioned(
                top: 4, right: 4,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _empty(ColorScheme cs) =>
      Center(child: Icon(Icons.image_outlined, size: 28, color: cs.onSurface.withValues(alpha: 0.2)));

  Widget _previewCard(ColorScheme cs, double price, List<String> photos) {
    final desc = _descCtrl.text.trim().isEmpty
        ? (widget.product.description ?? '')
        : _descCtrl.text.trim();

    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 110, width: 180,
            child: photos.isNotEmpty
                ? Image.network(photos.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _empty(cs))
                : Container(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    child: Center(child: Icon(Icons.image_outlined, size: 32, color: cs.onSurface.withValues(alpha: 0.2))),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.product.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(desc, style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.5)),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 6),
                Text('${price.toStringAsFixed(0)} сом',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF2ECC71))),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.storefront_rounded, size: 10, color: cs.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: 3),
                  Text('Ваш магазин', style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.4))),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
