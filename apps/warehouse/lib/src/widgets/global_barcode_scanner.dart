import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/inventory_providers.dart';
import '../providers/sales_providers.dart';
import '../providers/arrival_providers.dart';
import '../providers/transfer_providers.dart';
import '../screens/arrival/widgets/quick_create_product_dialog.dart';
import '../utils/snackbar_helper.dart';

/// Global barcode scanner listener.
/// Wraps the app shell and intercepts rapid keyboard input
/// (physical barcode scanners type fast and end with Enter).
/// Automatically routes scanned barcode to the correct handler
/// based on the current page.
class GlobalBarcodeScanner extends ConsumerStatefulWidget {
  final Widget child;
  final String currentPath;

  const GlobalBarcodeScanner({
    super.key,
    required this.child,
    required this.currentPath,
  });

  /// Called from camera scanner to route barcode through the same
  /// handler pipeline as a physical scanner.
  static void handleExternalBarcode(BuildContext context, String barcode) {
    final state = context.findAncestorStateOfType<_GlobalBarcodeScannerState>();
    if (state != null) {
      state._handleBarcode(barcode);
    }
  }

  @override
  ConsumerState<GlobalBarcodeScanner> createState() =>
      _GlobalBarcodeScannerState();
}

class _GlobalBarcodeScannerState extends ConsumerState<GlobalBarcodeScanner> {
  final StringBuffer _buffer = StringBuffer();
  DateTime _lastKeyTime = DateTime.now();

  // Max time between keystrokes to consider it a scanner (ms)
  static const _maxGap = Duration(milliseconds: 50);
  // Min length of a valid barcode
  static const _minBarcodeLength = 4;

  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onKey(KeyEvent event) {
    // Only handle key down events
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final now = DateTime.now();
    final gap = now.difference(_lastKeyTime);
    _lastKeyTime = now;

    // If gap is too large, this is manual typing — reset buffer
    if (gap > _maxGap) {
      _buffer.clear();
    }

    // Enter = submit the buffer
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final barcode = _buffer.toString().trim();
      _buffer.clear();

      if (barcode.length >= _minBarcodeLength) {
        // Check if a text field currently has focus — if so, let it handle
        final primaryFocus = FocusManager.instance.primaryFocus;
        final isTextFieldFocused = primaryFocus?.context != null &&
            primaryFocus!.context!
                .findAncestorWidgetOfExactType<EditableText>() !=
                null;
        if (!isTextFieldFocused) {
          _handleBarcode(barcode);
        }
      }
      return;
    }

    // Accumulate printable characters
    final char = event.character;
    if (char != null && char.length == 1) {
      _buffer.write(char);
    }
  }

  void _handleBarcode(String barcode) {
    final path = widget.currentPath;

    if (path.contains('/sales')) {
      _handleSalesBarcode(barcode);
    } else if (path.contains('/income')) {
      _handleArrivalBarcode(barcode);
    } else if (path.contains('/transfer')) {
      _handleTransferBarcode(barcode);
    } else if (path.contains('/inventory')) {
      _handleInventoryBarcode(barcode);
    }
  }

  void _handleTransferBarcode(String barcode) {
    final productsAsync = ref.read(inventoryProvider);
    final allProducts = productsAsync.value ?? [];
    final product =
        allProducts.where((p) => p.barcode == barcode).firstOrNull;

    if (product != null) {
      final added =
          ref.read(currentTransferProvider.notifier).addProduct(product);
      if (mounted) {
        if (added) {
          showInfoSnackBar(context, ref,
              '"${product.name}" добавлен в перемещение',
              duration: const Duration(seconds: 1));
        } else {
          showErrorSnackBar(context, '"${product.name}" — нет в наличии');
        }
      }
    } else {
      if (mounted) {
        showErrorSnackBar(context, 'Позиция с этим штрих-кодом не найдена');
      }
    }
  }

  void _handleInventoryBarcode(String barcode) {
    final productsAsync = ref.read(inventoryProvider);
    final allProducts = productsAsync.value ?? [];
    final product =
        allProducts.where((p) => p.barcode == barcode).firstOrNull;

    if (product != null) {
      // Navigate to product — set search query to highlight it
      ref.read(inventorySearchQueryProvider.notifier).state = barcode;
      if (mounted) {
        showInfoSnackBar(context, ref, 'Найден: "${product.name}"');
      }
    } else {
      if (mounted) {
        showErrorSnackBar(context, 'Товар с этим штрихкодом не найден');
      }
    }
  }

  void _handleSalesBarcode(String barcode) {
    final productsAsync = ref.read(inventoryProvider);
    final allProducts = productsAsync.value ?? [];
    final product =
        allProducts.where((p) => p.barcode == barcode).firstOrNull;

    if (product != null) {
      ref.read(cartProvider.notifier).addProduct(product);
      if (mounted) {
        showInfoSnackBar(context, ref, '"${product.name}" добавлен в чек', duration: const Duration(seconds: 1));
      }
    } else {
      if (mounted) {
        showErrorSnackBar(context, 'Позиция с этим штрих-кодом не существует');
      }
    }
  }

  void _handleArrivalBarcode(String barcode) {
    final productsAsync = ref.read(arrivalAllProductsProvider);
    final allProducts = productsAsync.value ?? [];
    final product =
        allProducts.where((p) => p.barcode == barcode).firstOrNull;

    if (product != null) {
      ref.read(currentArrivalProvider.notifier).addItem(product);
      if (mounted) {
        showInfoSnackBar(context, ref, '"${product.name}" добавлен в накладную', duration: const Duration(seconds: 1));
      }
    } else {
      // Offer to create new product
      if (mounted) {
        _offerCreateProduct(barcode);
      }
    }
  }

  Future<void> _offerCreateProduct(String barcode) async {
    final result = await showQuickCreateProductDialog(context, barcode);
    if (result != null && mounted) {
      ref.read(currentArrivalProvider.notifier)
          .addItem(result.product, quantity: result.quantity);
      ref.invalidate(arrivalAllProductsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: widget.child,
    );
  }
}
