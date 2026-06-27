import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_providers.dart';

// ═══════════════════════════════════════════════════════════════
//  Service Requests Provider — заявки клиентов на услуги
//
//  Клиенты заказывают услуги в Ак Жол → бизнес видит заявки здесь.
// ═══════════════════════════════════════════════════════════════

final _supabase = Supabase.instance.client;

class ServiceRequest {
  final String id;
  final String serviceId;
  final String serviceName;
  final String? customerPhone;
  final String address;
  final String? description;
  final String status;
  final double? priceFinal;
  final String? notes;
  final DateTime createdAt;

  const ServiceRequest({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    this.customerPhone,
    required this.address,
    this.description,
    required this.status,
    this.priceFinal,
    this.notes,
    required this.createdAt,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id'] as String,
      serviceId: json['service_id'] as String,
      serviceName: json['services']?['name'] as String? ?? 'Услуга',
      customerPhone: json['customer_phone'] as String?,
      address: json['address'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'pending',
      priceFinal: (json['price_final'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending': return 'Новая';
      case 'accepted': return 'Принята';
      case 'in_progress': return 'В работе';
      case 'completed': return 'Выполнена';
      case 'cancelled': return 'Отменена';
      default: return status;
    }
  }

  bool get isActive => status == 'pending' || status == 'accepted' || status == 'in_progress';
}

// ─── Provider ────────────────────────────────────────────────

final serviceRequestsProvider =
    StateNotifierProvider<ServiceRequestsNotifier, AsyncValue<List<ServiceRequest>>>((ref) {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  return ServiceRequestsNotifier(companyId);
});

class ServiceRequestsNotifier extends StateNotifier<AsyncValue<List<ServiceRequest>>> {
  final String? _companyId;

  ServiceRequestsNotifier(this._companyId) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (_companyId == null) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      state = const AsyncValue.loading();
      final data = await _supabase
          .from('service_requests')
          .select('*, services(name)')
          .eq('company_id', _companyId)
          .order('created_at', ascending: false)
          .limit(100);

      final items = (data as List)
          .map((e) => ServiceRequest.fromJson(e as Map<String, dynamic>))
          .toList();

      state = AsyncValue.data(items);
    } catch (e, st) {
      debugPrint('❌ serviceRequestsProvider error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> updateStatus(String requestId, String newStatus) async {
    try {
      await _supabase.from('service_requests').update({
        'status': newStatus,
      }).eq('id', requestId);
      await load();
      return true;
    } catch (e) {
      debugPrint('❌ updateStatus error: $e');
      return false;
    }
  }

  Future<bool> complete(String requestId, {double? priceFinal, String? notes}) async {
    try {
      final update = <String, dynamic>{
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      };
      if (priceFinal != null) update['price_final'] = priceFinal;
      if (notes != null) update['notes'] = notes;

      await _supabase.from('service_requests').update(update).eq('id', requestId);
      await load();
      return true;
    } catch (e) {
      debugPrint('❌ complete error: $e');
      return false;
    }
  }
}

/// Count of active (pending/accepted/in_progress) service requests
final activeServiceRequestsCountProvider = Provider<int>((ref) {
  final requestsAsync = ref.watch(serviceRequestsProvider);
  return requestsAsync.when(
    data: (requests) => requests.where((r) => r.isActive).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
