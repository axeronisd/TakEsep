import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/powersync_db.dart';
import 'auth_providers.dart';

class PaymentMethod {
  final String id;
  final String companyId;
  final String name;
  final bool isActive;
  final String? qrImageUrl;

  PaymentMethod({
    required this.id,
    required this.companyId,
    required this.name,
    required this.isActive,
    this.qrImageUrl,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      isActive: (json['is_active'] as int) == 1,
      qrImageUrl: json['qr_image_url'] as String?,
    );
  }
}

class PaymentMethodsNotifier extends StateNotifier<AsyncValue<List<PaymentMethod>>> {
  PaymentMethodsNotifier() : super(const AsyncValue.loading());

  void loadMethods(String companyId) async {
    state = const AsyncValue.loading();
    try {
      final rows = await powerSyncDb.getAll(
        'SELECT * FROM payment_methods WHERE company_id = ? ORDER BY created_at ASC',
        [companyId],
      );
      state = AsyncValue.data(rows.map((r) => PaymentMethod.fromJson(r)).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveMethod({
    required String companyId,
    String? id,
    required String name,
    required bool isActive,
    String? qrImageUrl,
  }) async {
    if (id == null) {
      // Insert
      await powerSyncDb.execute(
        '''INSERT INTO payment_methods (id, company_id, name, is_active, qr_image_url, created_at, updated_at) 
           VALUES (uuid(), ?, ?, ?, ?, datetime('now'), datetime('now'))''',
        [companyId, name, isActive ? 1 : 0, qrImageUrl],
      );
    } else {
      // Update
      await powerSyncDb.execute(
        '''UPDATE payment_methods SET name = ?, is_active = ?, qr_image_url = ?, updated_at = datetime('now') WHERE id = ?''',
        [name, isActive ? 1 : 0, qrImageUrl, id],
      );
    }
    loadMethods(companyId);
  }

  Future<void> toggleStatus(String id, bool active) async {
    await powerSyncDb.execute(
      'UPDATE payment_methods SET is_active = ?, updated_at = datetime("now") WHERE id = ?',
      [active ? 1 : 0, id],
    );
    // Reload directly reading the current company from state relies on an external param, 
    // but the proper way here is just invalidating the provider or re-fetching.
    // Instead of refetching the whole DB, we can just edit the state optimally.
    if (state.hasValue) {
      state = AsyncValue.data(
        state.value!.map((m) => m.id == id ? PaymentMethod(
          id: m.id, companyId: m.companyId, name: m.name, 
          isActive: active, qrImageUrl: m.qrImageUrl
        ) : m).toList()
      );
    }
  }

  Future<void> deleteMethod(String id) async {
    await powerSyncDb.execute('DELETE FROM payment_methods WHERE id = ?', [id]);
    if (state.hasValue) {
      state = AsyncValue.data(state.value!.where((m) => m.id != id).toList());
    }
  }
  void setEmpty() {
    state = const AsyncValue.data([]);
  }
}

final paymentMethodsProvider = StateNotifierProvider<PaymentMethodsNotifier, AsyncValue<List<PaymentMethod>>>((ref) {
  final companyId = ref.watch(authProvider.select((s) => s.currentCompany?.id));
  final notifier = PaymentMethodsNotifier();
  if (companyId != null) {
    notifier.loadMethods(companyId);
  } else {
    notifier.setEmpty();
  }
  return notifier;
});
