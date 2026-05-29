import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for real-time analytics data streaming.
/// Uses Supabase Realtime Stream API directly (not PowerSync).
class AnalyticsStreamService {
  final SupabaseClient _client;

  AnalyticsStreamService() : _client = Supabase.instance.client;

  /// Watch sales for a specific warehouse in real-time.
  /// Returns a Stream that emits the full list of sales whenever changes occur.
  /// 
  /// Uses Supabase Realtime Stream API with automatic reconnection on network restore.
  /// The stream filters by warehouse_id to ensure devices only receive their own data.
  Stream<List<Map<String, dynamic>>> watchSales(String warehouseId) {
    return _client
        .from('sales')
        .stream(primaryKey: ['id'])
        .eq('warehouse_id', warehouseId)
        .order('created_at', ascending: false);
  }

  /// Watch sales for a specific company (all warehouses).
  /// Returns a Stream that emits sales across all warehouses in the company.
  Stream<List<Map<String, dynamic>>> watchSalesByCompany(String companyId) {
    return _client
        .from('sales')
        .stream(primaryKey: ['id'])
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
  }

  /// Watch sales for a specific warehouse within a date range.
  /// Returns a Stream that emits sales filtered by date.
  Stream<List<Map<String, dynamic>>> watchSalesByDateRange({
    required String warehouseId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _client
        .from('sales')
        .stream(primaryKey: ['id'])
        .eq('warehouse_id', warehouseId)
        .gte('created_at', startDate.toIso8601String())
        .lte('created_at', endDate.toIso8601String())
        .order('created_at', ascending: false);
  }

  /// Watch arrivals for a specific warehouse in real-time.
  Stream<List<Map<String, dynamic>>> watchArrivals(String warehouseId) {
    return _client
        .from('arrivals')
        .stream(primaryKey: ['id'])
        .eq('warehouse_id', warehouseId)
        .order('created_at', ascending: false);
  }

  /// Watch transfers for a specific warehouse in real-time.
  Stream<List<Map<String, dynamic>>> watchTransfers(String warehouseId) {
    return _client
        .from('transfers')
        .stream(primaryKey: ['id'])
        .or('from_warehouse_id.eq.$warehouseId,to_warehouse_id.eq.$warehouseId')
        .order('created_at', ascending: false);
  }

  /// Watch audits for a specific warehouse in real-time.
  Stream<List<Map<String, dynamic>>> watchAudits(String warehouseId) {
    return _client
        .from('audits')
        .stream(primaryKey: ['id'])
        .eq('warehouse_id', warehouseId)
        .order('created_at', ascending: false);
  }

  /// Watch products for a specific warehouse in real-time.
  /// This is critical for syncing product quantities when sales, arrivals,
  /// transfers, or audits change the stock.
  Stream<List<Map<String, dynamic>>> watchProducts(String warehouseId) {
    return _client
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('warehouse_id', warehouseId)
        .order('name', ascending: true);
  }

  /// Watch products for a specific company (all warehouses).
  Stream<List<Map<String, dynamic>>> watchProductsByCompany(String companyId) {
    return _client
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('company_id', companyId)
        .order('name', ascending: true);
  }

  /// Watch sale items for a specific warehouse in real-time.
  /// Useful for tracking which products are being sold.
  Stream<List<Map<String, dynamic>>> watchSaleItems(String warehouseId) {
    return _client
        .from('sale_items')
        .stream(primaryKey: ['id'])
        .eq('warehouse_id', warehouseId)
        .order('created_at', ascending: false);
  }

  /// Watch arrival items for a specific warehouse in real-time.
  /// Useful for tracking which products are being received.
  Stream<List<Map<String, dynamic>>> watchArrivalItems(String warehouseId) {
    return _client
        .from('arrival_items')
        .stream(primaryKey: ['id'])
        .eq('warehouse_id', warehouseId)
        .order('created_at', ascending: false);
  }

  /// Watch transfer items for a specific warehouse in real-time.
  /// Useful for tracking which products are being transferred.
  Stream<List<Map<String, dynamic>>> watchTransferItems(String warehouseId) {
    return _client
        .from('transfer_items')
        .stream(primaryKey: ['id'])
        .or('from_warehouse_id.eq.$warehouseId,to_warehouse_id.eq.$warehouseId')
        .order('created_at', ascending: false);
  }

  /// Watch audit items for a specific warehouse in real-time.
  /// Useful for tracking which products are being audited.
  Stream<List<Map<String, dynamic>>> watchAuditItems(String warehouseId) {
    return _client
        .from('audit_items')
        .stream(primaryKey: ['id'])
        .eq('warehouse_id', warehouseId)
        .order('created_at', ascending: false);
  }
}

/// Singleton instance for easy access
final analyticsStreamService = AnalyticsStreamService();
