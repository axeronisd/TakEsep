import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/akjol_theme.dart';
import '../../providers/cart_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/favorites_provider.dart';
import 'modifier_sheet.dart';

// ═══════════════════════════════════════════════════════════════
//  SMART SEARCH HELPER — fuzzy + transliteration
// ═══════════════════════════════════════════════════════════════

class _SmartSearch {
  // Russian → Latin transliteration map
  static const _ruToEn = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e',
    'ё': 'yo', 'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k',
    'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r',
    'с': 's', 'т': 't', 'у': 'u', 'ф': 'f', 'х': 'h', 'ц': 'ts',
    'ч': 'ch', 'ш': 'sh', 'щ': 'sch', 'ъ': '', 'ы': 'y', 'ь': '',
    'э': 'e', 'ю': 'yu', 'я': 'ya',
  };

  static const _enToRu = {
    'a': 'а', 'b': 'б', 'c': 'к', 'd': 'д', 'e': 'е', 'f': 'ф',
    'g': 'г', 'h': 'х', 'i': 'и', 'j': 'дж', 'k': 'к', 'l': 'л',
    'm': 'м', 'n': 'н', 'o': 'о', 'p': 'п', 'q': 'к', 'r': 'р',
    's': 'с', 't': 'т', 'u': 'у', 'v': 'в', 'w': 'в', 'x': 'кс',
    'y': 'й', 'z': 'з',
  };

  static String _transliterate(String input, Map<String, String> map) {
    final buf = StringBuffer();
    for (final ch in input.split('')) {
      buf.write(map[ch] ?? ch);
    }
    return buf.toString();
  }

  /// Calculate simple Levenshtein distance for short strings
  static int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    if (a.length > 20 || b.length > 20) return a == b ? 0 : 99;

    final matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => i == 0 ? j : (j == 0 ? i : 0)),
    );

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    return matrix[a.length][b.length];
  }

  /// Smart match: exact, contains, transliterated, fuzzy
  static bool matches(String query, String name, {String? description}) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase().trim();
    final n = name.toLowerCase();
    final d = (description ?? '').toLowerCase();

    // 1. Direct contains
    if (n.contains(q) || d.contains(q)) return true;

    // 2. Transliterated search (cola → кола, кола → cola)
    final qRu = _transliterate(q, _enToRu);
    final qEn = _transliterate(q, _ruToEn);
    if (n.contains(qRu) || n.contains(qEn)) return true;
    if (d.contains(qRu) || d.contains(qEn)) return true;

    // 3. Fuzzy match (typo tolerance) — word-level
    final qWords = q.split(RegExp(r'\s+'));
    final nWords = n.split(RegExp(r'\s+'));
    for (final qw in qWords) {
      if (qw.length < 3) continue;
      for (final nw in nWords) {
        final maxDist = qw.length <= 4 ? 1 : 2;
        if (_levenshtein(qw, nw) <= maxDist) return true;
      }
    }

    return false;
  }
}

// ═══════════════════════════════════════════════════════════════
//  STORE SCREEN — Main screen
// ═══════════════════════════════════════════════════════════════

class StoreScreen extends ConsumerStatefulWidget {
  final String storeId;
  const StoreScreen({super.key, required this.storeId});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storeId = widget.storeId;
    final storeAsync = ref.watch(storeDetailProvider(storeId));
    final categoriesAsync =
        ref.watch(storeProductCategoriesProvider(storeId));
    final productsAsync = ref.watch(storeProductsProvider(storeId));
    final selectedCat =
        ref.watch(selectedProductCategoryProvider(storeId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F5F5),
      body: storeAsync.when(
        data: (store) {
          if (store == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined,
                      size: 64, color: AkJolTheme.textTertiary),
                  const SizedBox(height: 16),
                  Text('Магазин не найден',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AkJolTheme.textSecondary)),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Назад'),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // ── 1. Store Header ──
              _StoreHeader(store: store, isDark: isDark),

              // ── 2. Search bar ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _SearchBar(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    isDark: isDark,
                    onChanged: (q) => setState(() => _searchQuery = q),
                  ),
                ),
              ),

              // ── 3. Category grid (2 rows, scrollable) ──
              if (_searchQuery.isEmpty)
                categoriesAsync.when(
                  data: (categories) {
                    if (categories.isEmpty) {
                      return const SliverToBoxAdapter(
                          child: SizedBox(height: 8));
                    }
                    return SliverToBoxAdapter(
                      child: _CategoryGrid(
                        categories: categories,
                        selectedId: selectedCat,
                        isDark: isDark,
                        onTap: (id) {
                          final current = ref.read(
                              selectedProductCategoryProvider(storeId));
                          ref
                              .read(selectedProductCategoryProvider(storeId)
                                  .notifier)
                              .state = current == id ? null : id;
                        },
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                      child: SizedBox(height: 8)),
                  error: (_, __) => const SliverToBoxAdapter(
                      child: SizedBox(height: 8)),
                ),

              // ── 4. Selected category header ──
              if (selectedCat != null && _searchQuery.isEmpty)
                categoriesAsync.when(
                  data: (categories) {
                    final cat = categories.where((c) => c.id == selectedCat).firstOrNull;
                    if (cat == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    return SliverToBoxAdapter(
                      child: _SelectedCategoryHeader(
                        category: cat,
                        isDark: isDark,
                        onClear: () => ref
                            .read(selectedProductCategoryProvider(storeId).notifier)
                            .state = null,
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                  error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),

              // ── 5. Products grid ──
              productsAsync.when(
                data: (products) {
                  var filtered = selectedCat == null
                      ? products
                      : products.where((p) => p.categoryId == selectedCat).toList();

                  // Smart search filter
                  if (_searchQuery.isNotEmpty) {
                    filtered = filtered.where((p) {
                      return _SmartSearch.matches(
                        _searchQuery,
                        p.name,
                        description: p.b2cDescription,
                      );
                    }).toList();
                  }

                  if (filtered.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(
                        isSearch: _searchQuery.isNotEmpty,
                        isDark: isDark,
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio: 0.82,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _ProductCard(
                          product: filtered[i],
                          storeId: storeId,
                          storeName: store.name,
                        ),
                        childCount: filtered.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AkJolTheme.primary),
                  ),
                ),
                error: (_, __) => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Ошибка загрузки товаров')),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AkJolTheme.primary),
        ),
        error: (_, __) =>
            const Center(child: Text('Ошибка загрузки магазина')),
      ),

      // Cart badge is shown in the tab bar instead
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SEARCH BAR — with clear button
// ═══════════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final bool isDark;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.isDark,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final border =
        isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB);
    final hint =
        isDark ? const Color(0xFF484F58) : const Color(0xFF9CA3AF);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
        decoration: InputDecoration(
          hintText: 'Поиск товаров...',
          hintStyle: TextStyle(fontSize: 14, color: hint),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: hint),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: hint),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                    focusNode.unfocus();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  CATEGORY GRID — 2 rows, horizontal scroll, with images
// ═══════════════════════════════════════════════════════════════

class _CategoryGrid extends StatelessWidget {
  final List<StoreProductCategory> categories;
  final String? selectedId;
  final bool isDark;
  final void Function(String id) onTap;

  const _CategoryGrid({
    required this.categories,
    this.selectedId,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 2 rows layout
    final rowCount = categories.length > 4 ? 2 : 1;
    final height = rowCount == 2 ? 200.0 : 100.0;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GridView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: rowCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
          ),
          itemCount: categories.length,
          itemBuilder: (_, i) {
            final cat = categories[i];
            final isSelected = cat.id == selectedId;
            return _CategoryCard(
              category: cat,
              isSelected: isSelected,
              isDark: isDark,
              onTap: () => onTap(cat.id),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final StoreProductCategory category;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = category.imageUrl != null && category.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AkJolTheme.primary
                : (isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB)),
            width: isSelected ? 2 : 0.5,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AkJolTheme.primary.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background: image or gradient
            if (hasImage)
              Image.network(
                category.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _gradientFallback(),
              )
            else
              _gradientFallback(),

            // Dark overlay for text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),

            // Category name at bottom
            Positioned(
              left: 8, right: 8, bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      height: 1.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${category.productCount} шт',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            // Selected checkmark
            if (isSelected)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  width: 22, height: 22,
                  decoration: const BoxDecoration(
                    color: AkJolTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _gradientFallback() {
    final colors = [
      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      [const Color(0xFF11998E), const Color(0xFF38EF7D)],
      [const Color(0xFFFC5C7D), const Color(0xFF6A82FB)],
      [const Color(0xFFF093FB), const Color(0xFFF5576C)],
      [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
      [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
    ];
    final idx = category.name.hashCode.abs() % colors.length;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors[idx],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.category_rounded,
          size: 28,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SELECTED CATEGORY HEADER
// ═══════════════════════════════════════════════════════════════

class _SelectedCategoryHeader extends StatelessWidget {
  final StoreProductCategory category;
  final bool isDark;
  final VoidCallback onClear;

  const _SelectedCategoryHeader({
    required this.category,
    required this.isDark,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Text(
            category.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AkJolTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${category.productCount}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AkJolTheme.primary,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF21262D)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded, size: 14,
                      color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280)),
                  const SizedBox(width: 2),
                  Text('Все',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  EMPTY STATE
// ═══════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final bool isSearch;
  final bool isDark;
  const _EmptyState({required this.isSearch, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearch ? Icons.search_off_rounded : Icons.inventory_2_outlined,
            size: 56,
            color: AkJolTheme.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            isSearch ? 'Ничего не найдено' : 'Нет товаров',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AkJolTheme.textSecondary),
          ),
          if (isSearch) ...[
            const SizedBox(height: 4),
            Text(
              'Попробуйте изменить запрос',
              style: TextStyle(
                  fontSize: 13,
                  color: AkJolTheme.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  STORE HEADER — SliverAppBar with banner + logo
// ═══════════════════════════════════════════════════════════════

class _StoreHeader extends StatelessWidget {
  final StoreDetail store;
  final bool isDark;

  const _StoreHeader({required this.store, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final hasBanner =
        store.bannerUrl != null && store.bannerUrl!.isNotEmpty;
    final hasLogo =
        store.logoUrl != null && store.logoUrl!.isNotEmpty;

    return SliverAppBar(
      expandedHeight: 170,
      pinned: true,
      backgroundColor:
          isDark ? const Color(0xFF161B22) : Colors.white,
      foregroundColor:
          isDark ? Colors.white : const Color(0xFF111827),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Colors.white, size: 22),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (hasBanner)
              Image.network(
                store.bannerUrl!,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => _bannerFallback(isDark),
              )
            else
              _bannerFallback(isDark),
            
            // Gradient overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),

            // Logo + Name + Info
            Positioned(
              left: 16, bottom: 12, right: 16,
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasLogo
                        ? Image.network(store.logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => _logoFallback(store.name))
                        : _logoFallback(store.name),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          store.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (store.description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            store.description!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        // Schedule label
                        if (store.scheduleLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: store.isOpenNow ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                store.isOpenNow
                                    ? 'Открыто · ${store.scheduleLabel}'
                                    : 'Закрыто · ${store.scheduleLabel}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: store.isOpenNow
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : const Color(0xFFE74C3C),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (store.avgRating > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFC107)),
                          const SizedBox(width: 3),
                          Text(
                            store.avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _bannerFallback(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A2332), const Color(0xFF0D1117)]
              : [const Color(0xFF2ECC71), const Color(0xFF27AE60)],
        ),
      ),
      child: Center(
        child: Icon(Icons.storefront_rounded,
            size: 48,
            color: Colors.white.withValues(alpha: 0.3)),
      ),
    );
  }

  static Widget _logoFallback(String name) {
    return Container(
      color: AkJolTheme.primary.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AkJolTheme.primary,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PRODUCT CARD — Compact, premium, Wildberries-style
// ═══════════════════════════════════════════════════════════════

class _ProductCard extends ConsumerWidget {
  final StoreProduct product;
  final String storeId;
  final String storeName;

  const _ProductCard({
    required this.product,
    required this.storeId,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final borderColor =
        isDark ? const Color(0xFF21262D) : const Color(0xFFE8E8E8);

    final cart = ref.watch(cartProvider);
    final inCart = cart.items
        .where((i) => i.productId == product.id)
        .toList();
    final totalInCart =
        inCart.fold(0, (sum, item) => sum + item.quantity);

    return GestureDetector(
      onTap: () => _handleAdd(context, ref),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Image — square, fills most of card
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => _imageFallback(isDark),
                        )
                      : _imageFallback(isDark),
                  if (!product.isInStock)
                    Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: const Center(
                        child: Text('Нет в наличии',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 10)),
                      ),
                    ),
                  // Price badge top-left
                  Positioned(
                    left: 4, bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${product.b2cPrice.toStringAsFixed(0)} с',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Favorite
                  Positioned(
                    right: 4, top: 4,
                    child: _FavoriteButton(productId: product.id),
                  ),
                ],
              ),
            ),

            // Name
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 3, 5, 0),
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),

            // Bottom: full-width counter or add button
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 3, 4, 4),
              child: product.isInStock
                  ? (totalInCart == 0
                      ? _FullWidthAddBtn(onTap: () => _handleAdd(context, ref))
                      : _FullWidthCounter(
                          quantity: totalInCart,
                          onAdd: () => _handleAdd(context, ref),
                          onRemove: () {
                            if (inCart.isNotEmpty) {
                              final last = inCart.last;
                              ref.read(cartProvider.notifier)
                                  .updateQuantity(last.cartKey, last.quantity - 1);
                            }
                          },
                        ))
                  : const SizedBox(height: 26),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAdd(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);

    if (cart.isDifferentStore(storeId)) {
      final confirm = await showStoreConflictDialog(
        context,
        currentStoreName: cart.warehouseName ?? 'Магазин',
        newStoreName: storeName,
      );
      if (!confirm) return;
    }

    if (product.hasModifiers) {
      if (!context.mounted) return;
      final result = await showModifierSheet(context, product: product);
      if (result == null) return;

      if (cart.isDifferentStore(storeId)) {
        ref.read(cartProvider.notifier).clearAndAddItem(
              warehouseId: storeId, warehouseName: storeName,
              productId: product.id, name: product.name,
              price: product.b2cPrice, imageUrl: product.imageUrl,
              modifiers: result,
            );
      } else {
        ref.read(cartProvider.notifier).addItem(
              warehouseId: storeId, warehouseName: storeName,
              productId: product.id, name: product.name,
              price: product.b2cPrice, imageUrl: product.imageUrl,
              modifiers: result,
            );
      }
    } else {
      if (cart.isDifferentStore(storeId)) {
        ref.read(cartProvider.notifier).clearAndAddItem(
              warehouseId: storeId, warehouseName: storeName,
              productId: product.id, name: product.name,
              price: product.b2cPrice, imageUrl: product.imageUrl,
            );
      } else {
        ref.read(cartProvider.notifier).addItem(
              warehouseId: storeId, warehouseName: storeName,
              productId: product.id, name: product.name,
              price: product.b2cPrice, imageUrl: product.imageUrl,
            );
      }
    }
  }

  Widget _imageFallback(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF21262D) : const Color(0xFFF3F4F6),
      child: Center(
        child: Icon(
          Icons.image_outlined, size: 32,
          color: isDark ? const Color(0xFF484F58) : const Color(0xFFD1D5DB),
        ),
      ),
    );
  }
}

// ─── Full Width Add Button ───────────────────────────────────

class _FullWidthAddBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _FullWidthAddBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 26,
        decoration: BoxDecoration(
          color: AkJolTheme.primary,
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Center(
          child: Icon(Icons.add_rounded, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

// ─── Full Width Counter ──────────────────────────────────────

class _FullWidthCounter extends StatelessWidget {
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _FullWidthCounter({
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 26,
      decoration: BoxDecoration(
        color: AkJolTheme.primary,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: const Center(
                child: Icon(Icons.remove_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
          Text(
            '$quantity',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onAdd,
              behavior: HitTestBehavior.opaque,
              child: const Center(
                child: Icon(Icons.add_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// Heart button for adding/removing product from favorites
class _FavoriteButton extends ConsumerWidget {
  final String productId;
  const _FavoriteButton({required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final isFav = favorites.contains(productId);

    return GestureDetector(
      onTap: () => ref.read(favoritesProvider.notifier).toggle(productId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: isFav
              ? Colors.red.withValues(alpha: 0.9)
              : Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 14,
          color: Colors.white,
        ),
      ),
    );
  }
}
