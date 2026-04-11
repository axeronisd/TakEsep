import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/akjol_theme.dart';
import '../../providers/services_provider.dart';

/// ═══════════════════════════════════════════════════════════════
/// Services Screen — Услуги Ак Жол (из TakEsep Warehouse)
///
/// Бизнесы создают услуги в TakEsep → клиенты видят их здесь.
/// Фильтрация по категориям, поиск, заказ услуги.
/// ═══════════════════════════════════════════════════════════════

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(allServicesProvider);
    final categories = ref.watch(serviceCategoriesProvider);
    final selectedCategory = ref.watch(selectedServiceCategoryProvider);
    final filteredServices = ref.watch(searchedServicesProvider);

    final bg = _isDark ? const Color(0xFF0D1117) : const Color(0xFFFAFBFC);
    final mutedColor = _isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──
            SliverAppBar(
              pinned: true,
              title: const Text('Услуги',
                  style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              centerTitle: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _SearchBar(
                    controller: _searchCtrl,
                    isDark: _isDark,
                    onChanged: (value) {
                      ref.read(serviceSearchQueryProvider.notifier).state = value;
                    },
                  ),
                ),
              ),
            ),

            // ── Categories Chips ──
            if (categories.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: categories.length + 1, // +1 for "Все"
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return _CategoryChip(
                          label: 'Все',
                          isSelected: selectedCategory == null,
                          isDark: _isDark,
                          onTap: () => ref
                              .read(selectedServiceCategoryProvider.notifier)
                              .state = null,
                        );
                      }
                      final cat = categories[i - 1];
                      return _CategoryChip(
                        label: cat,
                        isSelected: selectedCategory == cat,
                        isDark: _isDark,
                        onTap: () => ref
                            .read(selectedServiceCategoryProvider.notifier)
                            .state = selectedCategory == cat ? null : cat,
                      );
                    },
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Content ──
            servicesAsync.when(
              data: (allServices) {
                if (filteredServices.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      hasSearch: _searchCtrl.text.isNotEmpty || selectedCategory != null,
                      isDark: _isDark,
                      onClear: () {
                        _searchCtrl.clear();
                        ref.read(serviceSearchQueryProvider.notifier).state = '';
                        ref.read(selectedServiceCategoryProvider.notifier).state = null;
                      },
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: filteredServices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final service = filteredServices[i];
                      return _ServiceCard(
                        service: service,
                        isDark: _isDark,
                        onTap: () => _showServiceDetail(service),
                      );
                    },
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AkJolTheme.primary)),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: mutedColor),
                      const SizedBox(height: 12),
                      Text('Не удалось загрузить услуги',
                          style: TextStyle(color: mutedColor)),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => ref.invalidate(allServicesProvider),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // ─── Service Detail Sheet ──────────────────────────────────

  void _showServiceDetail(CustomerService service) {
    final textColor = _isDark ? Colors.white : const Color(0xFF111827);
    final mutedColor = _isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final cardBg = _isDark ? const Color(0xFF161B22) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: cardBg,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),

            // Image
            if (service.imageUrl != null && service.imageUrl!.isNotEmpty)
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: service.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AkJolTheme.surfaceVariant,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AkJolTheme.surfaceVariant,
                    child: Icon(Icons.image, color: mutedColor, size: 48),
                  ),
                ),
              ),

            if (service.imageUrl != null) const SizedBox(height: 16),

            // Title + Price
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service.name,
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700, color: textColor)),
                      const SizedBox(height: 4),
                      if (service.category != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AkJolTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(service.category!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AkJolTheme.primary)),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(service.priceDisplay,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AkJolTheme.primary)),
                    if (service.durationDisplay.isNotEmpty)
                      Text(service.durationDisplay,
                          style: TextStyle(fontSize: 12, color: mutedColor)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Description
            if (service.description != null && service.description!.isNotEmpty) ...[
              Text(service.description!,
                  style: TextStyle(fontSize: 14, color: mutedColor, height: 1.5)),
              const SizedBox(height: 16),
            ],

            // Store info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  // Store logo
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AkJolTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: service.storeLogoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: service.storeLogoUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.storefront, color: AkJolTheme.primary),
                          )
                        : const Icon(Icons.storefront, color: AkJolTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(service.storeName,
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                        Text('Исполнитель услуги',
                            style: TextStyle(fontSize: 12, color: mutedColor)),
                      ],
                    ),
                  ),
                  if (service.warehouseId.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/store/${service.warehouseId}');
                      },
                      child: const Text('Открыть'),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Order button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => _orderService(ctx, service),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AkJolTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Заказать услугу',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('Оплата мастеру при выполнении',
                  style: TextStyle(fontSize: 12, color: mutedColor)),
            ),
          ],
        ),
      ),
    );
  }

  void _orderService(BuildContext ctx, CustomerService service) {
    Navigator.pop(ctx);
    
    // Show order form
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _ServiceOrderForm(
        service: service,
        isDark: _isDark,
        onSubmit: (address, description, phone) async {
          Navigator.pop(sheetCtx);
          
          // Save service request
          try {
            final user = Supabase.instance.client.auth.currentUser;
            await Supabase.instance.client.from('service_requests').insert({
              'service_id': service.id,
              'company_id': service.companyId,
              'customer_id': user?.id,
              'customer_phone': phone,
              'address': address,
              'description': description,
              'status': 'pending',
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Заявка на «${service.name}» отправлена'),
                  backgroundColor: AkJolTheme.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Заявка отправлена (оффлайн)'),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          }
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF21262D) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 15,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
        decoration: InputDecoration(
          hintText: 'Поиск услуг...',
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFF8B949E) : const Color(0xFF9CA3AF),
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.search, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AkJolTheme.primary
              : isDark
                  ? const Color(0xFF21262D)
                  : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(
                  color: isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFE5E7EB),
                  width: 0.5,
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : isDark
                    ? const Color(0xFF8B949E)
                    : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final CustomerService service;
  final bool isDark;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.service,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final mutedColor = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 0.5),
          boxShadow: isDark
              ? null
              : [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Image
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: AkJolTheme.primary.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: service.imageUrl != null && service.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: service.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _defaultIcon(),
                    )
                  : _defaultIcon(),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(service.name,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
                        maxLines: 1, overflow: TextOverflow.ellipsis),

                    const SizedBox(height: 3),

                    // Store name
                    Row(
                      children: [
                        Icon(Icons.storefront_outlined, size: 12, color: mutedColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(service.storeName,
                              style: TextStyle(fontSize: 12, color: mutedColor),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),

                    const SizedBox(height: 3),

                    // Category + Duration
                    Row(
                      children: [
                        if (service.category != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AkJolTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(service.category!,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AkJolTheme.primary)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (service.durationDisplay.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.schedule, size: 12, color: mutedColor),
                              const SizedBox(width: 2),
                              Text(service.durationDisplay,
                                  style: TextStyle(fontSize: 11, color: mutedColor)),
                            ],
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Price
                    Text(service.priceDisplay,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AkJolTheme.primary)),
                  ],
                ),
              ),
            ),

            // Arrow
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: mutedColor, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultIcon() {
    return Center(
      child: Icon(
        _categoryIcon(service.category),
        color: AkJolTheme.primary.withValues(alpha: 0.5),
        size: 32,
      ),
    );
  }

  IconData _categoryIcon(String? category) {
    if (category == null) return Icons.design_services_rounded;
    final lower = category.toLowerCase();
    if (lower.contains('сантехн')) return Icons.plumbing_rounded;
    if (lower.contains('электр')) return Icons.electrical_services_rounded;
    if (lower.contains('клининг') || lower.contains('убор')) return Icons.cleaning_services_rounded;
    if (lower.contains('ремонт')) return Icons.build_rounded;
    if (lower.contains('грузч') || lower.contains('переезд')) return Icons.local_shipping_rounded;
    if (lower.contains('it') || lower.contains('компьютер')) return Icons.computer_rounded;
    if (lower.contains('авто')) return Icons.car_repair_rounded;
    if (lower.contains('замк') || lower.contains('ключ')) return Icons.key_rounded;
    if (lower.contains('мебел')) return Icons.chair_rounded;
    if (lower.contains('кондиц')) return Icons.ac_unit_rounded;
    if (lower.contains('шве') || lower.contains('пошив')) return Icons.checkroom_rounded;
    if (lower.contains('сад')) return Icons.yard_rounded;
    return Icons.design_services_rounded;
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final bool isDark;
  final VoidCallback onClear;

  const _EmptyState({
    required this.hasSearch,
    required this.isDark,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AkJolTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasSearch ? Icons.search_off_rounded : Icons.design_services_outlined,
              size: 36,
              color: AkJolTheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'Ничего не найдено' : 'Услуг пока нет',
            style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasSearch
                ? 'Попробуйте изменить поиск или фильтр'
                : 'Бизнесы добавят свои услуги скоро',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF8B949E) : const Color(0xFF9CA3AF),
            ),
          ),
          if (hasSearch) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Сбросить'),
              style: TextButton.styleFrom(foregroundColor: AkJolTheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Service Order Form ─────────────────────────────────────

class _ServiceOrderForm extends StatefulWidget {
  final CustomerService service;
  final bool isDark;
  final void Function(String address, String description, String phone) onSubmit;

  const _ServiceOrderForm({
    required this.service,
    required this.isDark,
    required this.onSubmit,
  });

  @override
  State<_ServiceOrderForm> createState() => _ServiceOrderFormState();
}

class _ServiceOrderFormState extends State<_ServiceOrderForm> {
  final _addressCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _phoneCtrl.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : const Color(0xFF111827);
    final mutedColor = widget.isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),

          // Header
          Text('Заказать "${widget.service.name}"',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 4),
          Text('от ${widget.service.storeName} • ${widget.service.priceDisplay}',
              style: TextStyle(fontSize: 13, color: AkJolTheme.primary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),

          // Phone
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Ваш телефон',
              prefixIcon: Icon(Icons.phone_outlined, color: mutedColor, size: 20),
            ),
          ),
          const SizedBox(height: 12),

          // Address
          TextField(
            controller: _addressCtrl,
            decoration: InputDecoration(
              labelText: 'Адрес *',
              hintText: 'Укажите где нужна услуга',
              prefixIcon: Icon(Icons.location_on_outlined, color: mutedColor, size: 20),
            ),
          ),
          const SizedBox(height: 12),

          // Description
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Описание работы',
              hintText: 'Что нужно сделать...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),

          // Submit
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                if (_addressCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Укажите адрес')),
                  );
                  return;
                }
                widget.onSubmit(
                  _addressCtrl.text.trim(),
                  _descCtrl.text.trim(),
                  _phoneCtrl.text.trim(),
                );
              },
              child: const Text('Отправить заявку'),
            ),
          ),
        ],
      ),
    );
  }
}
