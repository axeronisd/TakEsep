import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../../providers/auth_providers.dart';
import '../../../data/powersync_db.dart';
import '../../../data/supabase_sync.dart';
import '../../../data/supabase_storage_helper.dart';
import '../../../utils/snackbar_helper.dart';

/// Bottom sheet allowing warehouse owner to set store logo + banner
/// for the customer-facing storefront.
class StorefrontSettingsSheet extends ConsumerStatefulWidget {
  const StorefrontSettingsSheet({super.key});

  @override
  ConsumerState<StorefrontSettingsSheet> createState() =>
      _StorefrontSettingsSheetState();
}

class _StorefrontSettingsSheetState
    extends ConsumerState<StorefrontSettingsSheet> {
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;

  String? _currentLogoUrl;
  String? _currentBannerUrl;
  String? _description;
  File? _newLogoFile;
  File? _newBannerFile;

  // Store categories (global marketplace categories)
  List<Map<String, dynamic>> _allCategories = [];
  Set<String> _selectedCategoryIds = {};

  // Product categories (local warehouse categories with images)
  List<Map<String, dynamic>> _productCategories = [];

  // Business hours
  TimeOfDay _workStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _workEnd = const TimeOfDay(hour: 22, minute: 0);
  bool _is24h = false;

  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController();
    _loadCurrent();
    _loadCategories();
    _loadProductCategories();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    final warehouseId = ref.read(authProvider).selectedWarehouseId;
    if (warehouseId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final data = await _supabase
          .from('delivery_settings')
          .select('logo_url, banner_url, description, work_start, work_end, is_24h')
          .eq('warehouse_id', warehouseId)
          .maybeSingle();

      if (data != null) {
        _currentLogoUrl = data['logo_url'] as String?;
        _currentBannerUrl = data['banner_url'] as String?;
        _description = data['description'] as String?;
        _descController.text = _description ?? '';
        _is24h = data['is_24h'] == true;
        final ws = data['work_start'] as String?;
        final we = data['work_end'] as String?;
        if (ws != null && ws.contains(':')) {
          final p = ws.split(':');
          _workStart = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
        }
        if (we != null && we.contains(':')) {
          final p = we.split(':');
          _workEnd = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
        }
      }
    } catch (e) {
      debugPrint('⚠️ Load storefront settings: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCategories() async {
    try {
      final data = await _supabase
          .from('store_categories')
          .select()
          .order('sort_order');
      
      debugPrint('📂 Loaded ${(data as List).length} store categories');
      
      Set<String> savedIds = {};
      final warehouseId = ref.read(authProvider).selectedWarehouseId;
      if (warehouseId != null) {
        try {
          final links = await _supabase
              .from('warehouse_store_categories')
              .select('store_category_id')
              .eq('warehouse_id', warehouseId);
          savedIds = Set<String>.from(
            (links as List).map((c) => c['store_category_id'] as String),
          );
          debugPrint('✅ Loaded ${savedIds.length} saved store category links');
        } catch (e) {
          debugPrint('⚠️ Load warehouse_store_categories: $e');
        }
      }

      if (mounted) {
        setState(() {
          _allCategories = List<Map<String, dynamic>>.from(data);
          _selectedCategoryIds = savedIds;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Load categories error: $e');
    }
  }

  Future<void> _loadProductCategories() async {
    try {
      final companyId = ref.read(authProvider).currentCompany?.id;
      if (companyId == null) return;

      // Load from local PowerSync DB (source of truth)
      final rows = await powerSyncDb.getAll(
        'SELECT id, name, image_url, company_id FROM categories WHERE company_id = ? ORDER BY name',
        [companyId],
      );

      debugPrint('📂 Loaded ${rows.length} product categories from local DB');

      if (mounted) {
        setState(() => _productCategories = rows.map((r) => Map<String, dynamic>.from(r)).toList());
      }

      // Auto-sync categories to Supabase (so customer app can read them)
      for (final cat in rows) {
        await SupabaseSync.upsert('categories', {
          'id': cat['id'],
          'company_id': cat['company_id'],
          'name': cat['name'],
          'image_url': cat['image_url'],
          'parent_id': cat['parent_id'],
        });
      }
    } catch (e) {
      debugPrint('⚠️ Load product categories error: $e');
    }
  }

  Future<void> _pickCategoryImage(String categoryId) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;

      final file = File(picked.path);
      if (!await file.exists()) return;

      if (mounted) showInfoSnackBar(context, ref, 'Загрузка...');

      // Upload to Supabase Storage
      final imageUrl = await SupabaseStorageHelper.uploadImage(file);

      // Update local PowerSync DB
      await powerSyncDb.execute(
        'UPDATE categories SET image_url = ? WHERE id = ?',
        [imageUrl, categoryId],
      );

      // Sync to Supabase
      await SupabaseSync.update('categories', categoryId, {
        'image_url': imageUrl,
      });

      if (mounted) {
        showInfoSnackBar(context, ref, 'Изображение обновлено');
        _loadProductCategories(); // Reload
      }
    } catch (e) {
      debugPrint('⚠️ Pick category image: $e');
      if (mounted) showErrorSnackBar(context, 'Ошибка: $e');
    }
  }

  Future<void> _pickImage(bool isLogo) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: isLogo ? 512 : 1920,
        maxHeight: isLogo ? 512 : 1080,
        imageQuality: 85,
      );
      if (picked == null) return;
      final file = File(picked.path);
      if (!await file.exists()) {
        if (mounted) showErrorSnackBar(context, 'Файл не найден');
        return;
      }
      setState(() {
        if (isLogo) {
          _newLogoFile = file;
        } else {
          _newBannerFile = file;
        }
      });
    } catch (e) {
      debugPrint('⚠️ Pick image: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Ошибка выбора изображения: $e');
      }
    }
  }

  Future<void> _save() async {
    final warehouseId = ref.read(authProvider).selectedWarehouseId;
    if (warehouseId == null) return;

    setState(() => _saving = true);

    try {
      String? logoUrl = _currentLogoUrl;
      String? bannerUrl = _currentBannerUrl;

      // Upload new logo if picked
      if (_newLogoFile != null) {
        logoUrl = await SupabaseStorageHelper.uploadImage(_newLogoFile!);
      }

      // Upload new banner if picked
      if (_newBannerFile != null) {
        bannerUrl =
            await SupabaseStorageHelper.uploadImage(_newBannerFile!);
      }

      // Upsert delivery_settings
      final wsStr = '${_workStart.hour.toString().padLeft(2, '0')}:${_workStart.minute.toString().padLeft(2, '0')}';
      final weStr = '${_workEnd.hour.toString().padLeft(2, '0')}:${_workEnd.minute.toString().padLeft(2, '0')}';
      await _supabase.from('delivery_settings').upsert({
        'warehouse_id': warehouseId,
        'logo_url': logoUrl,
        'banner_url': bannerUrl,
        'description': _descController.text.trim(),
        'is_active': true,
        'work_start': wsStr,
        'work_end': weStr,
        'is_24h': _is24h,
      }, onConflict: 'warehouse_id');

      // Save store categories BEFORE closing
      try {
        await _supabase.from('warehouse_store_categories').delete().eq('warehouse_id', warehouseId);
        if (_selectedCategoryIds.isNotEmpty) {
          await _supabase.from('warehouse_store_categories').insert(
            _selectedCategoryIds.map((catId) => <String, dynamic>{
              'warehouse_id': warehouseId,
              'store_category_id': catId,
            }).toList(),
          );
        }
        debugPrint('✅ Saved ${_selectedCategoryIds.length} store categories');
      } catch (e) {
        debugPrint('⚠️ Save categories error: $e');
      }

      if (mounted) {
        showInfoSnackBar(context, ref, 'Витрина обновлена!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Ошибка сохранения: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.lg,
        bottom:
            bottomInset > 0 ? bottomInset + AppSpacing.md : AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: _loading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      margin:
                          const EdgeInsets.only(bottom: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: cs.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.storefront_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Витрина магазина',
                              style: AppTypography.headlineMedium
                                  .copyWith(color: cs.onSurface)),
                          const SizedBox(height: 2),
                          Text(
                            'Логотип, баннер и описание для клиентов',
                            style: AppTypography.bodySmall.copyWith(
                                color: cs.onSurface
                                    .withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                    ),
                  ]),

                  const SizedBox(height: AppSpacing.xxl),

                  // ─── Banner Section ───
                  Text('БАННЕР',
                      style: AppTypography.labelSmall.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.4),
                          letterSpacing: 1.2)),
                  const SizedBox(height: AppSpacing.sm),
                  GestureDetector(
                    onTap: () => _pickImage(false),
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                            color: cs.outline.withValues(alpha: 0.2)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _newBannerFile != null
                          ? Stack(fit: StackFit.expand, children: [
                              Image.file(_newBannerFile!,
                                  fit: BoxFit.cover),
                              _imageOverlay('Нажмите чтобы заменить'),
                            ])
                          : _currentBannerUrl != null &&
                                  _currentBannerUrl!.isNotEmpty
                              ? Stack(fit: StackFit.expand, children: [
                                  Image.network(_currentBannerUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) =>
                                          _emptyImagePlaceholder(
                                              cs, false)),
                                  _imageOverlay(
                                      'Нажмите чтобы заменить'),
                                ])
                              : _emptyImagePlaceholder(cs, false),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // ─── Logo Section ───
                  Text('ЛОГОТИП',
                      style: AppTypography.labelSmall.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.4),
                          letterSpacing: 1.2)),
                  const SizedBox(height: AppSpacing.sm),
                  Row(children: [
                    GestureDetector(
                      onTap: () => _pickImage(true),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd),
                          border: Border.all(
                              color:
                                  cs.outline.withValues(alpha: 0.2)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _newLogoFile != null
                            ? Image.file(_newLogoFile!,
                                fit: BoxFit.cover)
                            : _currentLogoUrl != null &&
                                    _currentLogoUrl!.isNotEmpty
                                ? Image.network(_currentLogoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) =>
                                        _emptyImagePlaceholder(
                                            cs, true))
                                : _emptyImagePlaceholder(cs, true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Аватар магазина',
                              style: AppTypography.bodyMedium.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            'Квадратное изображение 512×512 px',
                            style: AppTypography.bodySmall.copyWith(
                                color: cs.onSurface
                                    .withValues(alpha: 0.5)),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _pickImage(true),
                            icon: const Icon(Icons.upload_rounded,
                                size: 16),
                            label: const Text('Выбрать'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),

                  const SizedBox(height: AppSpacing.xxl),

                  // ─── Description ───
                  Text('ОПИСАНИЕ',
                      style: AppTypography.labelSmall.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.4),
                          letterSpacing: 1.2)),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _descController,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText:
                          'Краткое описание вашего магазина для клиентов...',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 48),
                        child: Icon(Icons.description_rounded),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm)),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // ─── Business Hours ───
                  Text('ВРЕМЯ РАБОТЫ',
                      style: AppTypography.labelSmall.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.4),
                          letterSpacing: 1.2)),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Круглосуточно (24/7)',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                            Switch(
                              value: _is24h,
                              onChanged: (v) => setState(() => _is24h = v),
                              activeColor: cs.primary,
                            ),
                          ],
                        ),
                        if (!_is24h) ...[
                          const Divider(),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final t = await showTimePicker(
                                      context: context,
                                      initialTime: _workStart,
                                    );
                                    if (t != null) setState(() => _workStart = t);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: cs.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                                    ),
                                    child: Column(children: [
                                      Text('Открытие', style: TextStyle(fontSize: 11,
                                          color: cs.onSurface.withValues(alpha: 0.5))),
                                      Text('${_workStart.hour.toString().padLeft(2, '0')}:${_workStart.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                    ]),
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('—', style: TextStyle(fontSize: 18)),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final t = await showTimePicker(
                                      context: context,
                                      initialTime: _workEnd,
                                    );
                                    if (t != null) setState(() => _workEnd = t);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: cs.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                                    ),
                                    child: Column(children: [
                                      Text('Закрытие', style: TextStyle(fontSize: 11,
                                          color: cs.onSurface.withValues(alpha: 0.5))),
                                      Text('${_workEnd.hour.toString().padLeft(2, '0')}:${_workEnd.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                    ]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // ─── Categories ───
                  Text('КАТЕГОРИИ',
                      style: AppTypography.labelSmall.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.4),
                          letterSpacing: 1.2)),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Выберите категории для вашего магазина',
                      style: AppTypography.bodySmall.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5))),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: List.generate(_allCategories.length, (i) {
                        final cat = _allCategories[i];
                        final catId = cat['id'] as String;
                        final name = cat['name'] as String? ?? '';
                        final icon = cat['icon'] as String? ?? 'store';
                        final isSelected = _selectedCategoryIds.contains(catId);

                        return Column(
                          children: [
                            if (i > 0)
                              Divider(
                                height: 0.5,
                                thickness: 0.5,
                                color: cs.outline.withValues(alpha: 0.08),
                                indent: 52,
                              ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) _selectedCategoryIds.remove(catId);
                                    else _selectedCategoryIds.add(catId);
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.primary.withValues(alpha: 0.1)
                                              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          _catIcon(icon),
                                          size: 18,
                                          color: isSelected
                                              ? AppColors.primary
                                              : cs.onSurface.withValues(alpha: 0.45),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                            color: isSelected
                                                ? cs.onSurface
                                                : cs.onSurface.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ),
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.primary : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.primary
                                                : cs.outline.withValues(alpha: 0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // ─── Product Categories with Images ───
                  Text('КАТЕГОРИИ ТОВАРОВ',
                      style: AppTypography.labelSmall.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.4),
                          letterSpacing: 1.2)),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Загрузите изображения для категорий товаров',
                      style: AppTypography.bodySmall.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5))),
                  const SizedBox(height: AppSpacing.md),
                  if (_productCategories.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
                      ),
                      child: Center(
                        child: Text('Нет категорий. Создайте категории в разделе товаров.',
                            style: AppTypography.bodySmall.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.4))),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: _productCategories.length,
                      itemBuilder: (_, i) {
                        final cat = _productCategories[i];
                        final catId = cat['id'] as String;
                        final name = cat['name'] as String? ?? '';
                        final imageUrl = cat['image_url'] as String?;

                        return GestureDetector(
                          onTap: () => _pickCategoryImage(catId),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Image
                                if (imageUrl != null && imageUrl.isNotEmpty)
                                  Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Icon(Icons.broken_image_rounded,
                                          size: 32, color: cs.onSurface.withValues(alpha: 0.2)),
                                    ),
                                  )
                                else
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_rounded,
                                            size: 32, color: cs.onSurface.withValues(alpha: 0.2)),
                                        const SizedBox(height: 4),
                                        Text('Загрузить',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: cs.onSurface.withValues(alpha: 0.3))),
                                      ],
                                    ),
                                  ),
                                // Name label at bottom
                                Positioned(
                                  left: 0, right: 0, bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.7),
                                        ],
                                      ),
                                    ),
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: AppSpacing.xxl),

                  // ─── Save button ───
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _saving ? 'Сохранение...' : 'Сохранить витрину',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm)),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
    );
  }

  Widget _emptyImagePlaceholder(ColorScheme cs, bool isLogo) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isLogo ? Icons.add_a_photo_rounded : Icons.panorama_rounded,
            size: isLogo ? 28 : 36,
            color: cs.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 4),
          Text(
            isLogo ? 'Загрузить' : 'Нажмите для загрузки баннера',
            style: TextStyle(
              fontSize: isLogo ? 10 : 12,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageOverlay(String text) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.5),
            ],
          ),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  IconData _catIcon(String icon) {
    const map = {
      'pharmacy': Icons.local_pharmacy_rounded,
      'tech': Icons.devices_rounded,
      'food': Icons.fastfood_rounded,
      'grocery': Icons.shopping_basket_rounded,
      'clothing': Icons.checkroom_rounded,
      'home': Icons.home_rounded,
      'beauty': Icons.face_retouching_natural_rounded,
      'sports': Icons.sports_soccer_rounded,
      'books': Icons.menu_book_rounded,
      'toys': Icons.smart_toy_rounded,
      'flowers': Icons.local_florist_rounded,
      'pets': Icons.pets_rounded,
      'auto': Icons.directions_car_rounded,
      'store': Icons.storefront_rounded,
      'cafe': Icons.coffee_rounded,
      'restaurant': Icons.restaurant_rounded,
    };
    return map[icon] ?? Icons.storefront_rounded;
  }
}
