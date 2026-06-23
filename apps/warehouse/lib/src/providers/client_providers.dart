import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import '../data/client_repository.dart';
import '../data/supabase_realtime_service.dart';
import 'auth_providers.dart';

final clientRepositoryProvider =
    Provider<ClientRepository>((_) => ClientRepository());

/// Clients list for the current company with real-time updates.
/// Uses Supabase Realtime to automatically refresh when data changes on other devices.
final clientListProvider =
    StateNotifierProvider<ClientListNotifier, AsyncValue<List<Client>>>((ref) {
  final repo = ref.read(clientRepositoryProvider);
  final companyId = ref.watch(currentCompanyProvider)?.id;
  return ClientListNotifier(repo, companyId);
});

class ClientListNotifier extends StateNotifier<AsyncValue<List<Client>>> {
  final ClientRepository _repo;
  final String? _companyId;
  StreamSubscription? _subscription;

  ClientListNotifier(this._repo, this._companyId)
      : super(const AsyncValue.loading()) {
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    if (_companyId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    // Subscribe to real-time changes from Supabase
    final stream = realtimeService.subscribeToTable(
      table: 'clients',
      companyId: _companyId,
    );

    _subscription = stream.listen((data) {
      final items = data
          .map((row) => Client.fromJson(row))
          .toList();
      state = AsyncValue.data(items);
    }, onError: (e, st) {
      state = AsyncValue.error(e, st);
    });
  }

  Future<Client?> create({
    required String name,
    String? phone,
    String? email,
    String type = 'retail',
    String? notes,
  }) async {
    if (_companyId == null) return null;
    try {
      return await _repo.createClient(
        companyId: _companyId,
        name: name,
        phone: phone,
        email: email,
        type: type,
        notes: notes,
      );
    } catch (e) {
      return null;
    }
  }

  Future<bool> update({
    required String clientId,
    String? name,
    String? phone,
    String? email,
    String? type,
    bool? isActive,
  }) async {
    try {
      await _repo.updateClient(
        clientId: clientId,
        name: name,
        phone: phone,
        email: email,
        type: type,
        isActive: isActive,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> delete(String clientId) async {
    try {
      await _repo.deleteClient(clientId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Fetch sales history for a specific client
final clientSalesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, clientId) async {
  final repo = ref.read(clientRepositoryProvider);
  return repo.getClientSales(clientId);
});
