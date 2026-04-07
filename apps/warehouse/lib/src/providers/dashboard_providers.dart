import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:takesep_core/takesep_core.dart';
import '../data/dashboard_repository.dart';
import '../data/mock_data.dart';
import 'auth_providers.dart';
import 'date_filter_provider.dart';
import 'inventory_providers.dart';
import 'owner_settings_provider.dart';

// --- Dashboard Repository Provider ---
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

/// Selected warehouse ID. Initially null, gets set when data loads.
final selectedWarehouseProvider = StateProvider<String?>((ref) => null);

/// Current full warehouse object (async).
final currentWarehouseProvider = Provider<AsyncValue<Warehouse?>>((ref) {
  final warehousesAsync = ref.watch(warehousesProvider);
  final selectedId = ref.watch(selectedWarehouseProvider);

  return warehousesAsync.whenData((warehouses) {
    if (warehouses.isEmpty) return null;
    if (selectedId == null) return warehouses.first;
    return warehouses.firstWhere((w) => w.id == selectedId,
        orElse: () => warehouses.first);
  });
});

/// Current warehouse name from auth state.
final warehouseNameProvider = Provider<AsyncValue<String>>((ref) {
  final auth = ref.watch(authProvider);
  
  // Try selectedWarehouse getter first
  final selected = auth.selectedWarehouse;
  if (selected != null) return AsyncData(selected.name);
  
  // If warehouses available, use first one
  if (auth.availableWarehouses.isNotEmpty) {
    return AsyncData(auth.availableWarehouses.first.name);
  }

  // If auth is still loading
  if (auth.isLoading) return const AsyncLoading();
  
  // Final fallback — DB query
  return ref.watch(currentWarehouseProvider)
      .whenData((w) => w?.name ?? '');
});

/// ─── KPIs — from real Supabase data ───────────────────────
final dashboardKpisProvider =
    FutureProvider<List<DashboardKpi>>((ref) async {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  if (companyId == null) return [];

  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  final range = ref.watch(dateRangeProvider);
  final prevRange = ref.watch(prevPeriodProvider);
  final compareLabel = ref.watch(compareLabelProvider);
  final repo = ref.read(dashboardRepositoryProvider);

  // Current period
  final kpiData = await repo.getKpiData(
    companyId,
    range.start,
    range.end.add(const Duration(days: 1)),
    warehouseId: warehouseId,
  );

  // Previous period for comparison
  final prevKpiData = await repo.getKpiData(
    companyId,
    prevRange.start,
    prevRange.end.add(const Duration(days: 1)),
    warehouseId: warehouseId,
  );

  final salesCount = kpiData['salesCount'] as int;
  final avgCheck = kpiData['avgCheck'] as double;
  final totalIncome = kpiData['totalIncome'] as double;
  final auditLosses = (kpiData['auditLosses'] as num?)?.toDouble() ?? 0.0;
  final transferCosts = (kpiData['transferCosts'] as num?)?.toDouble() ?? 0.0;
  final writeOffCosts = (kpiData['writeOffCosts'] as num?)?.toDouble() ?? 0.0;
  final employeeExpenses = (kpiData['employeeExpenses'] as num?)?.toDouble() ?? 0.0;
  final arrivalAsExpense = ref.watch(arrivalAsExpenseProvider);
  final totalExpenses = (arrivalAsExpense ? totalIncome : 0.0) + auditLosses + transferCosts + writeOffCosts + employeeExpenses;

  // Recalculate net profit: the repository always deducts arrivals,
  // but if arrivalAsExpense is OFF we must add them back.
  final repoNetProfit = kpiData['netProfit'] as double;
  final netProfit = arrivalAsExpense ? repoNetProfit : repoNetProfit + totalIncome;

  final prevSalesCount = prevKpiData['salesCount'] as int;
  final prevAvgCheck = prevKpiData['avgCheck'] as double;
  final prevRepoNetProfit = prevKpiData['netProfit'] as double;
  final prevTotalIncome = prevKpiData['totalIncome'] as double;
  final prevAuditLosses = (prevKpiData['auditLosses'] as num?)?.toDouble() ?? 0.0;
  final prevTransferCosts = (prevKpiData['transferCosts'] as num?)?.toDouble() ?? 0.0;
  final prevWriteOffCosts = (prevKpiData['writeOffCosts'] as num?)?.toDouble() ?? 0.0;
  final prevEmployeeExpenses = (prevKpiData['employeeExpenses'] as num?)?.toDouble() ?? 0.0;
  final prevTotalExpenses = (arrivalAsExpense ? prevTotalIncome : 0.0) + prevAuditLosses + prevTransferCosts + prevWriteOffCosts + prevEmployeeExpenses;
  final prevNetProfit = arrivalAsExpense ? prevRepoNetProfit : prevRepoNetProfit + prevTotalIncome;

  double pct(double cur, double prev) {
    if (prev == 0) {
      if (cur > 0) return double.infinity;
      if (cur < 0) return double.negativeInfinity;
      return 0.0;
    }
    return ((cur - prev) / prev.abs()) * 100;
  }

  final isLoss = netProfit < 0;

  return [
    DashboardKpi(
        label: 'Расходы',
        value: totalExpenses,
        changePercent: pct(totalExpenses, prevTotalExpenses),
        compareLabel: compareLabel,
        icon: Icons.account_balance_rounded,
        iconColor: AppColors.warning),
    DashboardKpi(
        label: isLoss ? 'Убыток' : 'Чистая прибыль',
        value: netProfit.abs(),
        changePercent: pct(netProfit, prevNetProfit),
        compareLabel: compareLabel,
        icon: isLoss
            ? Icons.trending_down_rounded
            : Icons.account_balance_wallet_rounded,
        iconColor: isLoss ? AppColors.error : AppColors.primary),
    DashboardKpi(
        label: 'Продаж',
        value: salesCount.toDouble(),
        changePercent: pct(salesCount.toDouble(), prevSalesCount.toDouble()),
        compareLabel: compareLabel,
        icon: Icons.shopping_bag_rounded,
        iconColor: AppColors.info,
        isCurrency: false),
    DashboardKpi(
        label: 'Средний чек',
        value: avgCheck,
        changePercent: pct(avgCheck, prevAvgCheck),
        compareLabel: compareLabel,
        icon: Icons.receipt_rounded,
        iconColor: AppColors.warning),
    if (auditLosses > 0)
      DashboardKpi(
          label: 'Потери (ревизия)',
          value: auditLosses,
          changePercent: pct(auditLosses, prevAuditLosses),
          compareLabel: compareLabel,
          icon: Icons.warning_rounded,
          iconColor: AppColors.error),
  ];
});

/// ─── Chart data — from Supabase ──────────────────────────
final revenueChartProvider =
    FutureProvider<List<ChartPoint>>((ref) async {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  if (companyId == null) return [];

  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  final range = ref.watch(dateRangeProvider);
  final repo = ref.read(dashboardRepositoryProvider);

  return repo.getRevenueChartData(
    companyId,
    range.start,
    range.end.add(const Duration(days: 1)),
    warehouseId: warehouseId,
  );
});

/// Total revenue for chart.
final periodTotalProvider = Provider<AsyncValue<double>>((ref) {
  return ref.watch(revenueChartProvider).whenData(
      (data) => data.fold(0.0, (s, d) => s + d.revenue));
});

/// ─── Top products ──────────────────────────────────────────
final topLimitProvider = StateProvider<int>((ref) => 5);

final topProductsProvider =
    FutureProvider<List<TopProduct>>((ref) async {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  if (companyId == null) return [];

  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  final range = ref.watch(dateRangeProvider);
  final limit = ref.watch(topLimitProvider);
  final repo = ref.read(dashboardRepositoryProvider);

  return repo.getTopProducts(
    companyId,
    range.start,
    range.end.add(const Duration(days: 1)),
    limit: limit,
    warehouseId: warehouseId,
  );
});

final topExecutorsProvider =
    FutureProvider<List<TopExecutor>>((ref) async {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  if (companyId == null) return [];

  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  final range = ref.watch(dateRangeProvider);
  final limit = ref.watch(topLimitProvider);
  final repo = ref.read(dashboardRepositoryProvider);

  return repo.getTopExecutors(
    companyId,
    range.start,
    range.end.add(const Duration(days: 1)),
    limit: limit,
    warehouseId: warehouseId,
  );
});

final topClientsProvider =
    FutureProvider<List<TopClient>>((ref) async {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  if (companyId == null) return [];

  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  final range = ref.watch(dateRangeProvider);
  final limit = ref.watch(topLimitProvider);
  final repo = ref.read(dashboardRepositoryProvider);

  return repo.getTopClients(
    companyId,
    range.start,
    range.end.add(const Duration(days: 1)),
    limit: limit,
    warehouseId: warehouseId,
  );
});

/// ─── Operations ────────────────────────────────────────────

final recentOpsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  if (companyId == null) return [];

  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  final range = ref.watch(dateRangeProvider);
  final repo = ref.read(dashboardRepositoryProvider);

  return repo.getRecentOperations(
    companyId,
    range.start,
    range.end.add(const Duration(days: 1)),
    warehouseId: warehouseId,
  );
});

/// ─── Stock alerts ──────────────────────────────────────────
final stockSortFieldProvider =
    StateProvider<StockSortField>((ref) => StockSortField.quantity);
final stockSortAscProvider = StateProvider<bool>((ref) => true);

final stockAlertsProvider = FutureProvider<List<Product>>((ref) async {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  if (companyId == null) return [];

  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  final range = ref.watch(dateRangeProvider);
  final repo = ref.read(dashboardRepositoryProvider);
  final alerts = await repo.getStockAlertProducts(
    companyId,
    range.start,
    range.end.add(const Duration(days: 1)),
    warehouseId: warehouseId,
  );

  final field = ref.watch(stockSortFieldProvider);
  final asc = ref.watch(stockSortAscProvider);
  return sortStockAlerts(alerts, field, asc);
});

/// ─── Operations Summary (for Reports) ─────────────────────
final operationsSummaryProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  if (companyId == null) return {};

  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  final range = ref.watch(dateRangeProvider);
  final repo = ref.read(dashboardRepositoryProvider);

  return repo.getOperationsSummary(
    companyId,
    range.start,
    range.end.add(const Duration(days: 1)),
    warehouseId: warehouseId,
  );
});

/// ─── Employee filter for Reports ──────────────────────────
final employeeFilterProvider = StateProvider<String?>((ref) => null);

/// ─── KPI Breakdown (for expandable KPI cards) ─────────────
class KpiBreakdown {
  final double totalIncome;      // arrivals
  final double auditLosses;
  final double transferCosts;
  final double writeOffCosts;
  final double employeeExpenses;
  final double totalRevenue;
  final double netProfit;
  final int salesCount;
  final List<TopProduct> topProducts;
  final List<double> saleAmounts;  // individual sale totals (desc)
  final List<Map<String, dynamic>> auditShortages;

  const KpiBreakdown({
    this.totalIncome = 0,
    this.auditLosses = 0,
    this.transferCosts = 0,
    this.writeOffCosts = 0,
    this.employeeExpenses = 0,
    this.totalRevenue = 0,
    this.netProfit = 0,
    this.salesCount = 0,
    this.topProducts = const [],
    this.saleAmounts = const [],
    this.auditShortages = const [],
  });
}

final kpiBreakdownProvider = FutureProvider<KpiBreakdown>((ref) async {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  if (companyId == null) return const KpiBreakdown();

  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  final range = ref.watch(dateRangeProvider);
  final repo = ref.read(dashboardRepositoryProvider);

  final start = range.start;
  final end = range.end.add(const Duration(days: 1));

  final kpiData = await repo.getKpiData(companyId, start, end, warehouseId: warehouseId);
  final topProducts = await ref.watch(topProductsProvider.future);
  final saleAmounts = await repo.getSaleAmounts(companyId, start, end, warehouseId: warehouseId);
  final auditShortages = await repo.getAuditShortageItems(companyId, start, end, warehouseId: warehouseId);

  return KpiBreakdown(
    totalIncome: (kpiData['totalIncome'] as num?)?.toDouble() ?? 0,
    auditLosses: (kpiData['auditLosses'] as num?)?.toDouble() ?? 0,
    transferCosts: (kpiData['transferCosts'] as num?)?.toDouble() ?? 0,
    writeOffCosts: (kpiData['writeOffCosts'] as num?)?.toDouble() ?? 0,
    employeeExpenses: (kpiData['employeeExpenses'] as num?)?.toDouble() ?? 0,
    totalRevenue: (kpiData['totalRevenue'] as num?)?.toDouble() ?? 0,
    netProfit: (kpiData['netProfit'] as num?)?.toDouble() ?? 0,
    salesCount: (kpiData['salesCount'] as int?) ?? 0,
    topProducts: topProducts,
    saleAmounts: saleAmounts,
    auditShortages: auditShortages,
  );
});

/// ─── Goods vs Services breakdown (for analytics card) ────────
class GoodsServicesBreakdown {
  final double goodsTotal;
  final double goodsProfit;
  final double servicesTotal;
  final List<Map<String, dynamic>> goodsList;
  final List<Map<String, dynamic>> servicesList;

  const GoodsServicesBreakdown({
    this.goodsTotal = 0,
    this.goodsProfit = 0,
    this.servicesTotal = 0,
    this.goodsList = const [],
    this.servicesList = const [],
  });
}

final goodsServicesProvider = FutureProvider<GoodsServicesBreakdown>((ref) async {
  try {
    final companyId = ref.watch(currentCompanyProvider)?.id;
    if (companyId == null) return const GoodsServicesBreakdown();

    final warehouseId = ref.watch(selectedWarehouseIdProvider);
    final range = ref.watch(dateRangeProvider);
    final repo = ref.read(dashboardRepositoryProvider);

    final data = await repo.getGoodsServicesBreakdown(
      companyId,
      range.start,
      range.end.add(const Duration(days: 1)),
      warehouseId: warehouseId,
    );

    // PowerSync returns Row objects, not plain Maps — must convert
    final rawGoods = data['goodsList'];
    final rawServices = data['servicesList'];

    final goodsList = rawGoods is List
        ? rawGoods.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    final servicesList = rawServices is List
        ? rawServices.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    return GoodsServicesBreakdown(
      goodsTotal: (data['goodsTotal'] as num?)?.toDouble() ?? 0,
      goodsProfit: (data['goodsProfit'] as num?)?.toDouble() ?? 0,
      servicesTotal: (data['servicesTotal'] as num?)?.toDouble() ?? 0,
      goodsList: goodsList,
      servicesList: servicesList,
    );
  } catch (e) {
    debugPrint('goodsServicesProvider error: $e');
    return const GoodsServicesBreakdown();
  }
});
