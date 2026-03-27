import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/admin_repository.dart';

// --- Repository ---
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(Supabase.instance.client);
});

// --- Auth ---
final adminAuthProvider = StateProvider<bool>((ref) {
  final session = Supabase.instance.client.auth.currentSession;
  return session != null;
});

// --- Ecosystem Stats ---
final ecosystemStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return repo.getEcosystemStats();
});

// --- Companies ---
final companiesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return repo.getCompanies();
});

final selectedCompanyIdProvider = StateProvider<String?>((ref) => null);

final companyDetailsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, companyId) async {
  final repo = ref.read(adminRepositoryProvider);
  return repo.getCompanyDetails(companyId);
});

// --- Employees ---
final allEmployeesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return repo.getAllEmployees();
});

// --- Analytics ---
final revenueByCompanyProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return repo.getRevenueByCompany();
});
