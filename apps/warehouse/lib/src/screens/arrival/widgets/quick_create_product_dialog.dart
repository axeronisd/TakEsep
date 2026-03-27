import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../../providers/currency_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../providers/arrival_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/inventory_providers.dart';
import '../../../providers/storage_providers.dart';
import '../../../data/inventory_repository.dart';
import 'package:takesep_core/takesep_core.dart';
import 'image_crop_dialog.dart';

// ═══════════════════════════════════════════════════
//  PUBLIC API
// ═══════════════════════════════════════════════════

/// Result returned from the dialog — product + initial quantity.
class CreateProductResult {
  final Product product;
  final int quantity;
  const CreateProductResult({required this.product, required this.quantity});
}

/// Shows the Quick Create Product Dialog.
/// On mobile (<600px) opens as a full-screen page.
/// On desktop opens as a centered dialog.
Future<CreateProductResult?> showQuickCreateProductDialog(
    BuildContext context, String initialBarcode) {
  final isMobile = MediaQuery.of(context).size.width < 600;

  if (isMobile) {
    return Navigator.push<CreateProductResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _QuickCreateProductDialog(initialBarcode: initialBarcode),
      ),
    );
  }

  return showDialog<CreateProductResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        _QuickCreateProductDialog(initialBarcode: initialBarcode),
  );
}

// ═══════════════════════════════════════════════════
//  EAN-13 GENERATOR
// ═══════════════════════════════════════════════════

String generateEAN13() {
  final random = Random();
  const prefix = '200';
  final body = List.generate(9, (_) => random.nextInt(10)).join();
  final digits = '$prefix$body';
  int sum = 0;
  for (int i = 0; i < 12; i++) {
    sum += int.parse(digits[i]) * (i.isEven ? 1 : 3);
  }
  final check = (10 - (sum % 10)) % 10;
  return '$digits$check';
}

// ═══════════════════════════════════════════════════
//  CONSTANTS
// ═══════════════════════════════════════════════════

const List<String> _unitOptions = ['шт', 'кг', 'г', 'л', 'мл', 'уп', 'м'];

// ═══════════════════════════════════════════════════
//  DIALOG WIDGET
// ═══════════════════════════════════════════════════

class _QuickCreateProductDialog extends ConsumerStatefulWidget {
  final String initialBarcode;
  const _QuickCreateProductDialog({required this.initialBarcode});

  @override
  ConsumerState<_QuickCreateProductDialog> createState() =>
      _QuickCreateProductDialogState();
}

class _QuickCreateProductDialogState
    extends ConsumerState<_QuickCreateProductDialog> {
  // Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _priceController;
  late final TextEditingController _costController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _minStockController;
  late final TextEditingController _quantityController;
  late final TextEditingController _newCategoryNameController;

  // State
  File? _selectedImage;
  String? _selectedImageExtension;
  bool _isSaving = false;
  bool _isPublic = false;
  String _selectedUnit = 'шт';
  String? _selectedCategoryId;
  bool? _barcodeIsUnique;
  bool _checkingBarcode = false;
  bool _showNewCategoryForm = false;
  String? _newCategoryParentId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _barcodeController = TextEditingController(text: widget.initialBarcode);
    _priceController = TextEditingController();
    _costController = TextEditingController();
    _descriptionController = TextEditingController();
    _minStockController = TextEditingController();
    _quantityController = TextEditingController(text: '1');
    _newCategoryNameController = TextEditingController();

    if (widget.initialBarcode.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkBarcodeUniqueness(widget.initialBarcode);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _descriptionController.dispose();
    _minStockController.dispose();
    _quantityController.dispose();
    _newCategoryNameController.dispose();
    super.dispose();
  }

  // ─── Barcode Logic ───

  Future<void> _checkBarcodeUniqueness(String barcode) async {
    if (barcode.isEmpty) {
      setState(() => _barcodeIsUnique = null);
      return;
    }
    final companyId = ref.read(authProvider).currentCompany?.id;
    if (companyId == null) return;
    setState(() => _checkingBarcode = true);
    final isUnique = await ref
        .read(arrivalRepositoryProvider)
        .isBarcodeUnique(barcode, companyId);
    if (mounted) {
      setState(() {
        _barcodeIsUnique = isUnique;
        _checkingBarcode = false;
      });
    }
  }

  void _generateBarcode() async {
    final companyId = ref.read(authProvider).currentCompany?.id;
    if (companyId == null) return;
    setState(() => _checkingBarcode = true);
    String barcode;
    bool isUnique;
    int attempts = 0;
    do {
      barcode = generateEAN13();
      isUnique = await ref
          .read(arrivalRepositoryProvider)
          .isBarcodeUnique(barcode, companyId);
      attempts++;
    } while (!isUnique && attempts < 10);
    if (mounted) {
      setState(() {
        _barcodeController.text = barcode;
        _barcodeIsUnique = isUnique;
        _checkingBarcode = false;
      });
    }
  }

  // ─── Image Picker ───

  Future<void> _pickImageFromGallery() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      final rawFile = File(result.files.single.path!);
      final ext = result.files.single.extension ?? 'jpg';
      await _cropAndSetImage(rawFile, ext);
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (photo != null) {
        final rawFile = File(photo.path);
        final ext = photo.path.split('.').last;
        await _cropAndSetImage(rawFile, ext);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Камера недоступна на этом устройстве. Используйте Галерею.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _cropAndSetImage(File rawFile, String ext) async {
    if (!mounted) return;
    final croppedFile = await showImageCropDialog(context, rawFile);
    if (croppedFile != null && mounted) {
      setState(() {
        _selectedImage = croppedFile;
        _selectedImageExtension = ext;
      });
    }
  }

  // ─── Create Category ───

  Future<void> _createCategory() async {
    final name = _newCategoryNameController.text.trim();
    if (name.isEmpty) return;

    final companyId = ref.read(authProvider).currentCompany?.id;
    if (companyId == null) return;

    final newCategory = Category(
      id: const Uuid().v4(),
      companyId: companyId,
      name: name,
      parentId: _newCategoryParentId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final repo = InventoryRepository();
    final created = await repo.createCategory(newCategory);

    if (created != null && mounted) {
      ref.invalidate(categoriesProvider);
      setState(() {
        _selectedCategoryId = created.id;
        _showNewCategoryForm = false;
        _newCategoryNameController.clear();
        _newCategoryParentId = null;
      });
    }
  }

  // ─── Save Product ───

  Future<void> _saveProduct() async {
    final name = _nameController.text.trim();
    final barcode = _barcodeController.text.trim();
    final costStr = _costController.text.trim().replaceAll(',', '.');
    final priceStr = _priceController.text.trim().replaceAll(',', '.');
    final qty = int.tryParse(_quantityController.text.trim()) ?? 1;

    if (name.isEmpty) {
      _showError('Введите название товара');
      return;
    }
    if (priceStr.isEmpty) {
      _showError('Введите цену продажи');
      return;
    }
    if (barcode.isEmpty) {
      _showError('Введите или сгенерируйте штрихкод');
      return;
    }
    if (_barcodeIsUnique == false) {
      _showError('Этот штрихкод уже используется!');
      return;
    }

    final double price = double.tryParse(priceStr) ?? 0;
    final double cost = double.tryParse(costStr) ?? 0;
    final int minStock = int.tryParse(_minStockController.text.trim()) ?? 0;

    final companyId = ref.read(authProvider).currentCompany?.id;
    final warehouseId = ref.read(selectedWarehouseIdProvider) ?? '';
    if (companyId == null) {
      _showError('Ошибка сессии. Нет companyId.');
      return;
    }
    if (warehouseId.isEmpty) {
      _showError('Не выбран склад.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? imageUrl;
      if (_selectedImage != null && _selectedImageExtension != null) {
        final storageRepo = ref.read(storageRepositoryProvider);
        imageUrl = await storageRepo.uploadProductImage(
            _selectedImage!, _selectedImageExtension!);
      }

      final newProduct = Product(
        id: const Uuid().v4(),
        companyId: companyId,
        name: name,
        barcode: barcode,
        categoryId: _selectedCategoryId ?? 'uncategorized',
        price: price,
        costPrice: cost > 0 ? cost : null,
        b2cPrice: _isPublic ? price : null,
        quantity: 0,
        minQuantity: minStock,
        unit: _selectedUnit,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        warehouseId: warehouseId,
        imageUrl: imageUrl,
        isPublic: _isPublic,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success =
          await ref.read(arrivalRepositoryProvider).createProduct(newProduct);

      if (success && mounted) {
        ref.invalidate(arrivalAllProductsProvider);
        ref.invalidate(inventoryProvider);
        Navigator.pop(
            context, CreateProductResult(product: newProduct, quantity: qty));
      } else if (mounted) {
        throw Exception('Failed to insert product');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showError('Ошибка сохранения: $e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  // ═══════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final categoriesAsync = ref.watch(categoriesProvider);
    final cur = ref.watch(currencyProvider).symbol;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── Header ───
        Container(
          padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: isMobile ? 36 : 40,
                height: isMobile ? 36 : 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(Icons.add_box_rounded,
                    color: Colors.white, size: isMobile ? 20 : 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Новый товар',
                        style: (isMobile
                                ? AppTypography.headlineSmall
                                : AppTypography.headlineSmall)
                            .copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                                fontSize: isMobile ? 18 : null)),
                    if (!isMobile)
                      Text('Заполните информацию о товаре',
                          style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded,
                    color: cs.onSurface.withValues(alpha: 0.5)),
                style: IconButton.styleFrom(
                  backgroundColor:
                      cs.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),

        // ─── Scrollable Content ───
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Section: Фото ──
                _buildSectionLabel('Изображение', Icons.image_outlined),
                const SizedBox(height: AppSpacing.sm),
                _buildImagePicker(cs),
                SizedBox(height: isMobile ? AppSpacing.lg : AppSpacing.xl),

                // ── Section: Штрихкод ──
                _buildSectionLabel('Штрихкод', Icons.qr_code_2_rounded),
                const SizedBox(height: AppSpacing.sm),
                _buildBarcodeSection(cs),
                SizedBox(height: isMobile ? AppSpacing.lg : AppSpacing.xl),

                // ── Section: Основная информация ──
                _buildSectionLabel(
                    'Основная информация', Icons.info_outline_rounded),
                const SizedBox(height: AppSpacing.sm),
                _buildNameField(cs),
                const SizedBox(height: AppSpacing.md),
                _buildCategoryAndUnitRow(cs, categoriesAsync),
                SizedBox(height: isMobile ? AppSpacing.lg : AppSpacing.xl),

                // ── Section: Цены и количество ──
                _buildSectionLabel(
                    'Цены и количество', Icons.attach_money_rounded),
                const SizedBox(height: AppSpacing.sm),
                _buildPriceRow(cs, cur),
                const SizedBox(height: AppSpacing.md),
                _buildQuantityAndMinStockRow(cs),
                SizedBox(height: isMobile ? AppSpacing.lg : AppSpacing.xl),

                // ── Section: Дополнительно ──
                _buildSectionLabel('Дополнительно', Icons.tune_rounded),
                const SizedBox(height: AppSpacing.sm),
                _buildDescriptionField(cs),
                const SizedBox(height: AppSpacing.md),
                _buildB2CToggle(cs),
                // Extra bottom padding on mobile for keyboard
                if (isMobile) const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),

        // ─── Actions ───
        Container(
          padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isSaving ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                        vertical: isMobile ? 12 : 14),
                    side: BorderSide(
                        color: cs.outline.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  child: Text('Отмена',
                      style: AppTypography.labelLarge.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.7))),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: TEButton(
                  onPressed: _isSaving ? () {} : _saveProduct,
                  isLoading: _isSaving,
                  label: 'Сохранить',
                  icon: Icons.check_rounded,
                  isExpanded: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    // ─── Mobile: full-screen Scaffold ───
    if (isMobile) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(child: content),
      );
    }

    // ─── Desktop: Dialog ───
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 520,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 40,
              spreadRadius: 0,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: content,
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  SECTION BUILDER
  // ═══════════════════════════════════════════════════

  Widget _buildSectionLabel(String label, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(label,
            style: AppTypography.labelLarge.copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  //  IMAGE PICKER
  // ═══════════════════════════════════════════════════

  Widget _buildImagePicker(ColorScheme cs) {
    if (_selectedImage != null) {
      // Show preview with Edit and Change buttons
      return Center(
        child: SizedBox(
          width: 180,
          child: Column(
            children: [
              // Card-like preview
              Container(
                width: 180,
                height: 160,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(
                    color: cs.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusLg - 1),
                      child: Image.file(
                        _selectedImage!,
                        width: 180,
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Remove button
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedImage = null;
                          _selectedImageExtension = null;
                        }),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Edit + Change buttons
              Row(
                children: [
                  Expanded(
                    child: _ImageActionButton(
                      icon: Icons.crop_rounded,
                      label: 'Обрезать',
                      onTap: _isSaving
                          ? null
                          : () => _cropAndSetImage(
                              _selectedImage!, _selectedImageExtension ?? 'jpg'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ImageActionButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Изменить',
                      onTap: _isSaving ? null : _pickImageFromGallery,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Empty state — gallery + camera buttons
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Gallery
          _ImageSourceButton(
            icon: Icons.photo_library_outlined,
            label: 'Галерея',
            onTap: _isSaving ? null : _pickImageFromGallery,
            cs: cs,
          ),
          const SizedBox(width: AppSpacing.xl),
          // Camera
          _ImageSourceButton(
            icon: Icons.camera_alt_outlined,
            label: 'Камера',
            onTap: _isSaving ? null : _pickImageFromCamera,
            cs: cs,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  BARCODE SECTION
  // ═══════════════════════════════════════════════════

  Widget _buildBarcodeSection(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _barcodeController,
            enabled: !_isSaving,
            style: AppTypography.bodyLarge.copyWith(
              fontFamily: 'monospace',
              letterSpacing: 2,
              color: cs.onSurface,
            ),
            decoration: InputDecoration(
              labelText: 'Штрихкод',
              suffixIcon: _checkingBarcode
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2)))
                  : _barcodeIsUnique != null
                      ? Icon(
                          _barcodeIsUnique!
                              ? Icons.check_circle_rounded
                              : Icons.error_rounded,
                          color: _barcodeIsUnique!
                              ? AppColors.success
                              : AppColors.error,
                        )
                      : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (v) {
              if (v.length >= 4) {
                _checkBarcodeUniqueness(v);
              } else {
                setState(() => _barcodeIsUnique = null);
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 40,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _generateBarcode,
              icon: const Icon(Icons.autorenew_rounded, size: 18),
              label: const Text('Генерировать'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
            ),
          ),
          if (_barcodeIsUnique == false)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text('Этот штрихкод уже существует',
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.error)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  NAME FIELD
  // ═══════════════════════════════════════════════════

  Widget _buildNameField(ColorScheme cs) {
    return TextField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'Название товара *',
        prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.1),
      ),
      autofocus: widget.initialBarcode.isNotEmpty,
      enabled: !_isSaving,
      textInputAction: TextInputAction.next,
    );
  }

  // ═══════════════════════════════════════════════════
  //  CATEGORY + UNIT ROW
  // ═══════════════════════════════════════════════════

  Widget _buildCategoryDropdownWidget(
      ColorScheme cs, AsyncValue<List<Category>> categoriesAsync) {
    return categoriesAsync.when(
      data: (categories) {
        final parentCategories =
            categories.where((c) => c.parentId == null).toList();
        final childCategories =
            categories.where((c) => c.parentId != null).toList();
        final validValue = (_selectedCategoryId != null &&
                categories.any((c) => c.id == _selectedCategoryId))
            ? _selectedCategoryId
            : null;

        return DropdownButtonFormField<String>(
          initialValue: validValue,
          decoration: InputDecoration(
            labelText: 'Категория',
            prefixIcon: const Icon(Icons.category_outlined, size: 20),
            isDense: true,
            filled: true,
            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.1),
          ),
          isExpanded: true,
          items: [
            const DropdownMenuItem(
                value: null,
                child: Text('Без категории',
                    style: TextStyle(fontStyle: FontStyle.italic))),
            for (final parent in parentCategories) ...[
              DropdownMenuItem(
                value: parent.id,
                child: Text(parent.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              for (final child in childCategories
                  .where((c) => c.parentId == parent.id))
                DropdownMenuItem(
                  value: child.id,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text('↳ ${child.name}',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
            ],
            for (final cat in categories.where((c) =>
                c.parentId != null &&
                !parentCategories.any((p) => p.id == c.parentId)))
              DropdownMenuItem(
                value: cat.id,
                child: Text(cat.name),
              ),
          ],
          onChanged: _isSaving
              ? null
              : (v) => setState(() => _selectedCategoryId = v),
        );
      },
      loading: () => const TextField(
        enabled: false,
        decoration: InputDecoration(
            labelText: 'Категория', hintText: 'Загрузка...'),
      ),
      error: (_, __) => const TextField(
        enabled: false,
        decoration: InputDecoration(
            labelText: 'Категория', hintText: 'Ошибка'),
      ),
    );
  }

  Widget _buildAddCategoryButton() {
    return SizedBox(
      height: 48,
      child: IconButton(
        onPressed: _isSaving
            ? null
            : () => setState(
                () => _showNewCategoryForm = !_showNewCategoryForm),
        icon: Icon(
          _showNewCategoryForm ? Icons.close_rounded : Icons.add_rounded,
          color: AppColors.primary,
          size: 20,
        ),
        tooltip: 'Создать категорию',
        style: IconButton.styleFrom(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
    );
  }

  Widget _buildUnitDropdown(ColorScheme cs, {double? width}) {
    final dropdown = DropdownButtonFormField<String>(
      initialValue: _selectedUnit,
      decoration: InputDecoration(
        labelText: width != null ? 'Ед.' : 'Ед. измерения',
        isDense: true,
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.1),
      ),
      items: _unitOptions
          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
          .toList(),
      onChanged: _isSaving
          ? null
          : (v) => setState(() => _selectedUnit = v ?? 'шт'),
    );
    if (width != null) {
      return SizedBox(width: width, child: dropdown);
    }
    return dropdown;
  }

  Widget _buildCategoryAndUnitRow(
      ColorScheme cs, AsyncValue<List<Category>> categoriesAsync) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isMobile) ...[
          // Mobile: category full width
          _buildCategoryDropdownWidget(cs, categoriesAsync),
          const SizedBox(height: AppSpacing.sm),
          // Add-category button + unit picker side by side
          Row(
            children: [
              _buildAddCategoryButton(),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _buildUnitDropdown(cs)),
            ],
          ),
        ] else ...[
          // Desktop: all in one row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildCategoryDropdownWidget(cs, categoriesAsync),
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildAddCategoryButton(),
              const SizedBox(width: AppSpacing.sm),
              _buildUnitDropdown(cs, width: 90),
            ],
          ),
        ],

        // ── Inline Category Creation ──
        if (_showNewCategoryForm) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Новая категория',
                    style: AppTypography.labelLarge.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _newCategoryNameController,
                  decoration: const InputDecoration(
                    labelText: 'Название категории *',
                    prefixIcon: Icon(Icons.label_outline, size: 18),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _createCategory(),
                ),
                const SizedBox(height: AppSpacing.sm),
                categoriesAsync.when(
                  data: (categories) {
                    final parents =
                        categories.where((c) => c.parentId == null).toList();
                    return DropdownButtonFormField<String>(
                      initialValue: _newCategoryParentId,
                      decoration: const InputDecoration(
                        labelText: 'Поместить в (для подкатегории)',
                        helperText: 'Оставьте пустым для основной категории',
                        prefixIcon: Icon(Icons.account_tree_outlined, size: 18),
                        isDense: true,
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                            value: null,
                            child: Text('Нет (основная)',
                                style: TextStyle(fontStyle: FontStyle.italic))),
                        ...parents.map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            )),
                      ],
                      onChanged: (v) =>
                          setState(() => _newCategoryParentId = v),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 36,
                  child: FilledButton.icon(
                    onPressed: _createCategory,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Создать'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      textStyle: AppTypography.labelMedium,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  //  PRICES ROW
  // ═══════════════════════════════════════════════════

  Widget _buildPriceRow(ColorScheme cs, String cur) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final costField = TextField(
      controller: _costController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Закупка ($cur)',
        hintText: '0',
        prefixIcon: const Icon(Icons.arrow_downward_rounded,
            size: 18, color: AppColors.success),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.1),
      ),
      enabled: !_isSaving,
      textInputAction: TextInputAction.next,
    );
    final priceField = TextField(
      controller: _priceController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Продажа ($cur) *',
        hintText: '0',
        prefixIcon: const Icon(Icons.arrow_upward_rounded,
            size: 18, color: AppColors.primary),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.1),
      ),
      enabled: !_isSaving,
      textInputAction: TextInputAction.next,
    );

    if (isMobile) {
      return Column(
        children: [
          costField,
          const SizedBox(height: AppSpacing.sm),
          priceField,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: costField),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: priceField),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  //  QUANTITY + MIN STOCK ROW
  // ═══════════════════════════════════════════════════

  Widget _buildQuantityAndMinStockRow(ColorScheme cs) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final qtyField = TextField(
      controller: _quantityController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Количество *',
        prefixIcon: const Icon(Icons.shopping_cart_outlined,
            size: 18, color: AppColors.info),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.1),
      ),
      enabled: !_isSaving,
      textInputAction: TextInputAction.next,
    );
    final minField = TextField(
      controller: _minStockController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Мин. остаток',
        hintText: '0',
        prefixIcon: const Icon(Icons.notification_important_outlined,
            size: 18, color: AppColors.warning),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.1),
      ),
      enabled: !_isSaving,
    );

    if (isMobile) {
      return Column(
        children: [
          qtyField,
          const SizedBox(height: AppSpacing.sm),
          minField,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: qtyField),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: minField),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  //  DESCRIPTION FIELD
  // ═══════════════════════════════════════════════════

  Widget _buildDescriptionField(ColorScheme cs) {
    return TextField(
      controller: _descriptionController,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: 'Описание (необязательно)',
        prefixIcon: const Icon(Icons.description_outlined, size: 20),
        alignLabelWithHint: true,
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.1),
      ),
      enabled: !_isSaving,
    );
  }

  // ═══════════════════════════════════════════════════
  //  B2C TOGGLE
  // ═══════════════════════════════════════════════════

  Widget _buildB2CToggle(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: _isPublic
            ? AppColors.primary.withValues(alpha: 0.06)
            : cs.surfaceContainerHighest.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: _isPublic
              ? AppColors.primary.withValues(alpha: 0.3)
              : cs.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.delivery_dining_outlined,
              size: 20,
              color: _isPublic
                  ? AppColors.primary
                  : cs.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Показывать в приложении доставки',
                    style: AppTypography.labelMedium
                        .copyWith(color: cs.onSurface)),
                Text('Клиенты смогут заказывать онлайн',
                    style: AppTypography.labelSmall
                        .copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          Switch(
            value: _isPublic,
            onChanged: _isSaving ? null : (v) => setState(() => _isPublic = v),
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

/// Small icon+label button for image source selection (Gallery / Camera).
class _ImageSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final ColorScheme cs;

  const _ImageSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(icon, size: 24, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label,
              style: AppTypography.labelSmall.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Compact action button shown below the image preview (Edit / Change).
class _ImageActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ImageActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(label,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
