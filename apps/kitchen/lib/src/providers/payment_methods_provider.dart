import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/powersync_db.dart';
import '../data/supabase_sync.dart';
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
    final now = DateTime.now().toIso8601String();
    if (id == null) {
      final newId = const Uuid().v4();
      await powerSyncDb.execute(
        '''INSERT INTO payment_methods (id, company_id, name, is_active, qr_image_url, created_at, updated_at) 
           VALUES (?, ?, ?, ?, ?, ?, ?)''',
        [newId, companyId, name, isActive ? 1 : 0, qrImageUrl, now, now],
      );
      await SupabaseSync.upsert('payment_methods', {
        'id': newId, 'company_id': companyId, 'name': name,
        'is_active': isActive, 'qr_image_url': qrImageUrl,
        'created_at': now, 'updated_at': now,
      });
    } else {
      await powerSyncDb.execute(
        '''UPDATE payment_methods SET name = ?, is_active = ?, qr_image_url = ?, updated_at = ? WHERE id = ?''',
        [name, isActive ? 1 : 0, qrImageUrl, now, id],
      );
      await SupabaseSync.update('payment_methods', id, {
        'name': name, 'is_active': isActive, 'qr_image_url': qrImageUrl, 'updated_at': now,
      });
    }
    loadMethods(companyId);
  }

  Future<void> toggleStatus(String id, bool active) async {
    await powerSyncDb.execute(
      'UPDATE payment_methods SET is_active = ?, updated_at = datetime("now") WHERE id = ?',
      [active ? 1 : 0, id],
    );
    await SupabaseSync.update('payment_methods', id, {'is_active': active});
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
    await SupabaseSync.delete('payment_methods', id);
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
