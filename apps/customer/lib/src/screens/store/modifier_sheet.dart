import 'package:flutter/material.dart';
import '../../theme/akjol_theme.dart';
import '../../providers/cart_provider.dart';
import '../../providers/store_provider.dart';

/// Opens a modal bottom sheet for selecting product modifiers.
/// Returns null if cancelled, or a list of selected CartModifiers.
Future<List<CartModifier>?> showModifierSheet(
  BuildContext context, {
  required StoreProduct product,
}) async {
  return showModalBottomSheet<List<CartModifier>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ModifierSheet(product: product),
  );
}

class _ModifierSheet extends StatefulWidget {
  final StoreProduct product;
  const _ModifierSheet({required this.product});

  @override
  State<_ModifierSheet> createState() => _ModifierSheetState();
}

class _ModifierSheetState extends State<_ModifierSheet> {
  // groupId → set of selected modifier ids
  late Map<String, Set<String>> _selections;

  @override
  void initState() {
    super.initState();
    _selections = {};

    // Pre-select defaults
    for (final group in widget.product.modifierGroups) {
      _selections[group.id] = {};
      for (final mod in group.modifiers) {
        if (mod.isDefault && mod.isAvailable) {
          _selections[group.id]!.add(mod.id);
        }
      }
      // For required_one, if no default, select first available
      if (group.type == 'required_one' &&
          _selections[group.id]!.isEmpty) {
        final first = group.modifiers
            .where((m) => m.isAvailable)
            .firstOrNull;
        if (first != null) {
          _selections[group.id]!.add(first.id);
        }
      }
    }
  }

  double get _totalPrice {
    double total = widget.product.b2cPrice;
    for (final group in widget.product.modifierGroups) {
      final selected = _selections[group.id] ?? {};
      for (final mod in group.modifiers) {
        if (selected.contains(mod.id)) {
          total += mod.priceDelta;
        }
      }
    }
    return total;
  }

  bool get _isValid {
    for (final group in widget.product.modifierGroups) {
      final selected = _selections[group.id] ?? {};
      if (group.type == 'required_one' && selected.isEmpty) {
        return false;
      }
      if (group.type == 'required_many' &&
          selected.length < group.minSelections) {
        return false;
      }
    }
    return true;
  }

  List<CartModifier> _buildResult() {
    final result = <CartModifier>[];
    for (final group in widget.product.modifierGroups) {
      final selected = _selections[group.id] ?? {};
      for (final mod in group.modifiers) {
        if (selected.contains(mod.id)) {
          result.add(CartModifier(
            modifierId: mod.id,
            groupName: group.name,
            name: mod.name,
            priceDelta: mod.priceDelta,
          ));
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final muted =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: muted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Product header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                // Image
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: isDark
                        ? const Color(0xFF21262D)
                        : const Color(0xFFF3F4F6),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.product.imageUrl != null
                      ? Image.network(
                          widget.product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.image_outlined,
                            color: muted,
                          ),
                        )
                      : Icon(Icons.image_outlined, color: muted),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.product.b2cDescription != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.product.b2cDescription!,
                          style: TextStyle(
                              fontSize: 12, color: muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Modifier groups
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: widget.product.modifierGroups
                    .map((g) => _ModifierGroupSection(
                          group: g,
                          selected: _selections[g.id] ?? {},
                          onChanged: (modId, selected) {
                            setState(() {
                              _toggleModifier(g, modId, selected);
                            });
                          },
                        ))
                    .toList(),
              ),
            ),
          ),

          // Bottom bar: total + add button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: bg,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? const Color(0xFF21262D)
                      : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: ElevatedButton(
                onPressed: _isValid
                    ? () => Navigator.pop(context, _buildResult())
                    : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  disabledBackgroundColor: isDark
                      ? const Color(0xFF21262D)
                      : const Color(0xFFE5E7EB),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Добавить'),
                    const SizedBox(width: 8),
                    Text(
                      '${_totalPrice.toStringAsFixed(0)} сом',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleModifier(
      ModifierGroupData group, String modId, bool selected) {
    final set = _selections[group.id]!;

    if (group.type == 'required_one') {
      // Radio behavior
      set.clear();
      if (selected) set.add(modId);
    } else {
      // Checkbox behavior
      if (selected) {
        if (group.maxSelections > 0 &&
            set.length >= group.maxSelections) {
          return; // Max reached
        }
        set.add(modId);
      } else {
        set.remove(modId);
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  MODIFIER GROUP SECTION
// ═══════════════════════════════════════════════════════════════

class _ModifierGroupSection extends StatelessWidget {
  final ModifierGroupData group;
  final Set<String> selected;
  final void Function(String modId, bool selected) onChanged;

  const _ModifierGroupSection({
    required this.group,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final muted =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);

    String subtitle = '';
    if (group.type == 'required_one') {
      subtitle = 'Обязательно · выберите 1';
    } else if (group.type == 'required_many') {
      subtitle =
          'Обязательно · мин ${group.minSelections}';
    } else {
      subtitle = 'Необязательно';
      if (group.maxSelections > 0) {
        subtitle += ' · макс ${group.maxSelections}';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
        ...group.modifiers.map((mod) {
          final isSelected = selected.contains(mod.id);
          final isRadio = group.type == 'required_one';

          return ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20),
            title: Text(
              mod.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                color: mod.isAvailable
                    ? textColor
                    : muted,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mod.priceDelta != 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      mod.priceDelta > 0
                          ? '+${mod.priceDelta.toStringAsFixed(0)}'
                          : mod.priceDelta.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: mod.priceDelta > 0
                            ? AkJolTheme.primary
                            : AkJolTheme.error,
                      ),
                    ),
                  ),
                if (isRadio)
                  Radio<bool>(
                    value: true,
                    groupValue: isSelected ? true : null,
                    onChanged: mod.isAvailable
                        ? (_) => onChanged(mod.id, true)
                        : null,
                    activeColor: AkJolTheme.primary,
                  )
                else
                  Checkbox(
                    value: isSelected,
                    onChanged: mod.isAvailable
                        ? (v) => onChanged(mod.id, v ?? false)
                        : null,
                    activeColor: AkJolTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            onTap: mod.isAvailable
                ? () {
                    if (isRadio) {
                      onChanged(mod.id, true);
                    } else {
                      onChanged(mod.id, !isSelected);
                    }
                  }
                : null,
          );
        }),
        const Divider(height: 1, indent: 20, endIndent: 20),
      ],
    );
  }
}
