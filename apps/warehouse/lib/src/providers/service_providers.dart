import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import '../data/service_repository.dart';
import 'auth_providers.dart';

final serviceRepositoryProvider = Provider<ServiceRepository>((_) => ServiceRepository());

/// Services list for the current company.
final serviceListProvider =
    StateNotifierProvider<ServiceListNotifier, AsyncValue<List<Service>>>((ref) {
  final repo = ref.read(serviceRepositoryProvider);
  final companyId = ref.watch(currentCompanyProvider)?.id;
  return ServiceListNotifier(repo, companyId);
});

class ServiceListNotifier extends StateNotifier<AsyncValue<List<Service>>> {
  final ServiceRepository _repo;
  final String? _companyId;

  ServiceListNotifier(this._repo, this._companyId)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (_companyId == null) { state = const AsyncValue.data([]); return; }
    try {
      state = const AsyncValue.loading();
      final items = await _repo.getServices(_companyId);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Service?> create({
    required String name,
    String? category,
    String? description,
    required double price,
    int durationMinutes = 0,
    String? imageUrl,
  }) async {
    if (_companyId == null) return null;
    try {
      final svc = await _repo.createService(
        companyId: _companyId, name: name, category: category,
        description: description, price: price, durationMinutes: durationMinutes,
        imageUrl: imageUrl,
      );
      await load();
      return svc;
    } catch (e) {
      return null;
    }
  }

  Future<bool> update({required String serviceId, String? name, double? price, String? category, bool? isActive, String? imageUrl, bool clearImage = false}) async {
    try {
      await _repo.updateService(serviceId: serviceId, name: name, price: price, category: category, isActive: isActive, imageUrl: imageUrl, clearImage: clearImage);
      await load();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> delete(String serviceId) async {
    try {
      await _repo.deleteService(serviceId);
      await load();
      return true;
    } catch (_) { return false; }
  }
}
