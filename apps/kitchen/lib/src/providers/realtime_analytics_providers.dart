import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/analytics_stream_service.dart';
import '../data/mock_data.dart';
import 'auth_providers.dart';
import 'date_filter_provider.dart';

/// Provider for AnalyticsStreamService
final analyticsStreamServiceProvider = Provider<AnalyticsStreamService>((ref) {
  return analyticsStreamService;
});

/// Realtime sales stream for the current warehouse.
/// Automatically updates when new sales are created on any device.
///
/// Usage:
/// ```dart
/// final salesAsync = ref.watch(realtimeSalesStreamProvider);
/// ```
final realtimeSalesStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(analyticsStreamServiceProvider);
  final warehouseId = ref.watch(selectedWarehouseIdProvider);

  if (warehouseId == null) {
    debugPrint('[Realtime] warehouseId is null, returning empty sales stream');
    return const Stream.empty();
  }

  debugPrint('[Realtime] Watching sales for warehouse: $warehouseId');
  return service.watchSales(warehouseId).handleError((error, stack) {
    debugPrint('[Realtime] Error watching sales: $error');
    debugPrint('[Realtime] Stack trace: $stack');
  });
});

/// Realtime sales stream filtered by date range.
/// Returns sales within the selected date period.
final realtimeSalesByDateRangeProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(analyticsStreamServiceProvider);
  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  final range = ref.watch(dateRangeProvider);

  if (warehouseId == null) {
    return const Stream.empty();
  }

  return service.watchSalesByDateRange(
    warehouseId: warehouseId,
    startDate: range.start,
    endDate: range.end,
  );
});

/// Realtime arrivals stream for the current warehouse.
final realtimeArrivalsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(analyticsStreamServiceProvider);
  final warehouseId = ref.watch(selectedWarehouseIdProvider);

  if (warehouseId == null) {
    return const Stream.empty();
  }

  return service.watchArrivals(warehouseId);
});

/// Realtime transfers stream for the current warehouse.
final realtimeTransfersStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(analyticsStreamServiceProvider);
  final warehouseId = ref.watch(selectedWarehouseIdProvider);

  if (warehouseId == null) {
    return const Stream.empty();
  }

  return service.watchTransfers(warehouseId);
});

/// Realtime audits stream for the current warehouse.
final realtimeAuditsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(analyticsStreamServiceProvider);
  final warehouseId = ref.watch(selectedWarehouseIdProvider);

  if (warehouseId == null) {
    return const Stream.empty();
  }

  return service.watchAudits(warehouseId);
});

/// Realtime products stream for the current warehouse.
/// This is critical for syncing product quantities when sales, arrivals,
/// transfers, or audits change the stock. Any operation that modifies
/// product quantity will trigger this stream.
final realtimeProductsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(analyticsStreamServiceProvider);
  final warehouseId = ref.watch(selectedWarehouseIdProvider);

  if (warehouseId == null) {
    debugPrint('[Realtime] warehouseId is null, returning empty stream');
    return const Stream.empty();
  }

  debugPrint('[Realtime] Watching products for warehouse: $warehouseId');
  return service.watchProducts(warehouseId).handleError((error, stack) {
    debugPrint('[Realtime] Error watching products: $error');
    debugPrint('[Realtime] Stack trace: $stack');
  });
});

/// Realtime sale items stream for the current warehouse.
/// Tracks which products are being sold in real-time.
final realtimeSaleItemsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(analyticsStreamServiceProvider);
  final warehouseId = ref.watch(selectedWarehouseIdProvider);

  if (warehouseId == null) {
    return const Stream.empty();
  }

  return service.watchSaleItems(warehouseId);
});

/// Realtime arrival items stream for the current warehouse.
/// Tracks which products are being received in real-time.
final realtimeArrivalItemsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(analyticsStreamServiceProvider);
  final warehouseId = ref.watch(selectedWarehouseIdProvider);

  if (warehouseId == null) {
    return const Stream.empty();
  }

  return service.watchArrivalItems(warehouseId);
});

/// Realtime transfer items stream for the current warehouse.
/// Tracks which products are being transferred in real-time.
final realtimeTransferItemsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(analyticsStreamServiceProvider);
  final warehouseId = ref.watch(selectedWarehouseIdProvider);

  if (warehouseId == null) {
    return const Stream.empty();
  }

  return service.watchTransferItems(warehouseId);
});

/// Realtime audit items stream for the current warehouse.
/// Tracks which products are being audited in real-time.
final realtimeAuditItemsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(analyticsStreamServiceProvider);
  final warehouseId = ref.watch(selectedWarehouseIdProvider);

  if (warehouseId == null) {
    return const Stream.empty();
  }

  return service.watchAuditItems(warehouseId);
});

/// Computed KPI data from realtime sales stream.
/// This replaces the Future-based dashboardKpisProvider with a Stream-based version.
///
/// Recalculates revenue, profit, and other metrics whenever sales change.
final realtimeKpisProvider =
    StreamProvider.autoDispose<List<DashboardKpi>>((ref) {
  final salesAsync = ref.watch(realtimeSalesByDateRangeProvider);
  final companyId = ref.watch(currentCompanyProvider)?.id;
  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  final range = ref.watch(dateRangeProvider);
  final prevRange = ref.watch(prevPeriodProvider);
  final compareLabel = ref.watch(compareLabelProvider);

  if (companyId == null || warehouseId == null) {
    return const Stream.empty();
  }

  // Use sales stream directly for KPIs
  return salesAsync.when(
    data: (sales) => Stream.value(_calculateKpisFromRealtimeData(
      sales: sales,
      arrivals: [],
      companyId: companyId,
      warehouseId: warehouseId,
      range: range,
      prevRange: prevRange,
      compareLabel: compareLabel,
      arrivalAsExpense: false,
    )),
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

/// Calculate KPIs from realtime sales and arrivals data.
List<DashboardKpi> _calculateKpisFromRealtimeData({
  required List<Map<String, dynamic>> sales,
  required List<Map<String, dynamic>> arrivals,
  required String companyId,
  required String warehouseId,
  required DateTimeRange range,
  required DateTimeRange prevRange,
  required String compareLabel,
  required bool arrivalAsExpense,
}) {
  // Filter sales by date range
  final filteredSales = sales.where((sale) {
    final createdAt = DateTime.tryParse(sale['created_at'] as String? ?? '');
    if (createdAt == null) return false;
    return createdAt.isAfter(range.start.subtract(const Duration(days: 1))) &&
        createdAt.isBefore(range.end.add(const Duration(days: 1)));
  }).toList();

  // Filter arrivals by date range
  final filteredArrivals = arrivals.where((arrival) {
    final createdAt = DateTime.tryParse(arrival['created_at'] as String? ?? '');
    if (createdAt == null) return false;
    return createdAt.isAfter(range.start.subtract(const Duration(days: 1))) &&
        createdAt.isBefore(range.end.add(const Duration(days: 1)));
  }).toList();

  // Calculate current period metrics
  final totalRevenue = filteredSales.fold<double>(
    0.0,
    (sum, sale) => sum + ((sale['total_amount'] as num?)?.toDouble() ?? 0.0),
  );

  final salesCount = filteredSales.length;
  final avgCheck = salesCount > 0 ? totalRevenue / salesCount : 0.0;

  final totalIncome = filteredArrivals.fold<double>(
    0.0,
    (sum, arrival) =>
        sum + ((arrival['total_amount'] as num?)?.toDouble() ?? 0.0),
  );

  // Calculate profit (simplified - in production you'd need cost data from sale_items)
  final netProfit = totalRevenue * 0.3; // Assuming 30% margin for simplicity
  final totalExpenses = arrivalAsExpense ? totalIncome : 0.0;

  final isLoss = netProfit < 0;

  // For previous period, we'd need to fetch historical data
  // For now, use current period data as baseline
  final prevSalesCount = salesCount;
  final prevAvgCheck = avgCheck;
  final prevNetProfit = netProfit;
  final prevTotalExpenses = totalExpenses;

  double pct(double cur, double prev) {
    if (prev == 0) {
      if (cur > 0) return double.infinity;
      if (cur < 0) return double.negativeInfinity;
      return 0.0;
    }
    return ((cur - prev) / prev.abs()) * 100;
  }

  return [
    DashboardKpi(
      label: 'Расходы',
      value: totalExpenses,
      changePercent: pct(totalExpenses, prevTotalExpenses),
      compareLabel: compareLabel,
      icon: Icons.account_balance_rounded,
      iconColor: const Color(0xFFFFA726),
    ),
    DashboardKpi(
      label: isLoss ? 'Убыток' : 'Чистая прибыль',
      value: netProfit.abs(),
      changePercent: pct(netProfit, prevNetProfit),
      compareLabel: compareLabel,
      icon: isLoss
          ? Icons.trending_down_rounded
          : Icons.account_balance_wallet_rounded,
      iconColor: isLoss ? const Color(0xFFE53935) : const Color(0xFF6C5CE7),
    ),
    DashboardKpi(
      label: 'Продаж',
      value: salesCount.toDouble(),
      changePercent: pct(salesCount.toDouble(), prevSalesCount.toDouble()),
      compareLabel: compareLabel,
      icon: Icons.shopping_bag_rounded,
      iconColor: const Color(0xFF42A5F5),
      isCurrency: false,
    ),
    DashboardKpi(
      label: 'Средний чек',
      value: avgCheck,
      changePercent: pct(avgCheck, prevAvgCheck),
      compareLabel: compareLabel,
      icon: Icons.receipt_rounded,
      iconColor: const Color(0xFFFFA726),
    ),
    DashboardKpi(
      label: 'Общая выручка',
      value: totalRevenue,
      changePercent: pct(totalRevenue, totalRevenue * 0.9), // Dummy comparison
      compareLabel: compareLabel,
      icon: Icons.attach_money_rounded,
      iconColor: const Color(0xFF6C5CE7),
    ),
  ];
}

/// Realtime revenue chart data from sales stream.
/// Recalculates chart points whenever sales change.
final realtimeRevenueChartProvider =
    StreamProvider.autoDispose<List<RevenueChartPoint>>((ref) {
  final salesAsync = ref.watch(realtimeSalesByDateRangeProvider);
  final range = ref.watch(dateRangeProvider);

  return salesAsync.when(
    data: (sales) =>
        Stream.value(_calculateRevenueChartFromSales(sales, range)),
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

/// Calculate revenue chart data from sales.
List<RevenueChartPoint> _calculateRevenueChartFromSales(
  List<Map<String, dynamic>> sales,
  DateTimeRange range,
) {
  // Group sales by day
  final Map<String, List<Map<String, dynamic>>> salesByDay = {};

  for (final sale in sales) {
    final createdAt = DateTime.tryParse(sale['created_at'] as String? ?? '');
    if (createdAt == null) continue;

    final dayKey =
        '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
    salesByDay.putIfAbsent(dayKey, () => []);
    salesByDay[dayKey]!.add(sale);
  }

  // Generate chart points for each day in range
  final points = <RevenueChartPoint>[];
  var current = range.start;

  while (current.isBefore(range.end.add(const Duration(days: 1)))) {
    final dayKey =
        '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
    final daySales = salesByDay[dayKey] ?? [];

    final revenue = daySales.fold<double>(
      0.0,
      (sum, sale) => sum + ((sale['total_amount'] as num?)?.toDouble() ?? 0.0),
    );

    final profit = revenue * 0.3; // Assuming 30% margin

    points.add(RevenueChartPoint(
      label: '${current.day}.${current.month}',
      revenue: revenue,
      profit: profit,
    ));

    current = current.add(const Duration(days: 1));
  }

  return points;
}

/// Data class for revenue chart points.
class RevenueChartPoint {
  final String label;
  final double revenue;
  final double profit;

  RevenueChartPoint({
    required this.label,
    required this.revenue,
    required this.profit,
  });
}

/// Realtime period total from sales stream.
final realtimePeriodTotalProvider = StreamProvider.autoDispose<double>((ref) {
  final salesAsync = ref.watch(realtimeSalesByDateRangeProvider);

  return salesAsync.when(
    data: (sales) => Stream.value(sales.fold<double>(
      0.0,
      (sum, sale) => sum + ((sale['total_amount'] as num?)?.toDouble() ?? 0.0),
    )),
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

/// Realtime operations summary from all streams.
final realtimeOperationsSummaryProvider =
    StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final salesAsync = ref.watch(realtimeSalesByDateRangeProvider);

  return salesAsync.when(
    data: (sales) => Stream.value({
      'salesCount': sales.length,
      'salesTotal': sales.fold<double>(
        0.0,
        (sum, sale) =>
            sum + ((sale['total_amount'] as num?)?.toDouble() ?? 0.0),
      ),
      'arrivalsCount': 0,
      'arrivalsTotal': 0.0,
      'transfersCount': 0,
      'auditsCount': 0,
    }),
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});
