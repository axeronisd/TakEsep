import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import '../data/client_repository.dart';
import 'auth_providers.dart';

final clientRepositoryProvider = Provider<ClientRepository>((_) => ClientRepository());

/// Clients list for the current company.
final clientListProvider =
    StateNotifierProvider<ClientListNotifier, AsyncValue<List<Client>>>((ref) {
  final repo = ref.read(clientRepositoryProvider);
  final companyId = ref.watch(currentCompanyProvider)?.id;
  return ClientListNotifier(repo, companyId);
});

class ClientListNotifier extends StateNotifier<AsyncValue<List<Client>>> {
  final ClientRepository _repo;
  final String? _companyId;

  ClientListNotifier(this._repo, this._companyId)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (_companyId == null) { state = const AsyncValue.data([]); return; }
    try {
      state = const AsyncValue.loading();
      final items = await _repo.getClients(_companyId);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
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
      final client = await _repo.createClient(
        companyId: _companyId, name: name, phone: phone,
        email: email, type: type, notes: notes,
      );
      await load();
      return client;
    } catch (e) {
      return null;
    }
  }

  Future<bool> update({required String clientId, String? name, String? phone, String? email, String? type, bool? isActive}) async {
    try {
      await _repo.updateClient(clientId: clientId, name: name, phone: phone, email: email, type: type, isActive: isActive);
      await load();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> delete(String clientId) async {
    try {
      await _repo.deleteClient(clientId);
      await load();
      return true;
    } catch (_) { return false; }
  }
}

/// Fetch sales history for a specific client
final clientSalesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, clientId) async {
  final repo = ref.read(clientRepositoryProvider);
  return repo.getClientSales(clientId);
});
