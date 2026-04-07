import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/courier_auth_service.dart';

/// Global courier profile — set after successful login
final courierProfileProvider =
    StateProvider<CourierProfile?>((ref) => null);

/// Convenience: courier ID
final courierIdProvider = Provider<String?>((ref) {
  return ref.watch(courierProfileProvider)?.id;
});

/// Convenience: is store courier?
final isStoreCourierProvider = Provider<bool>((ref) {
  return ref.watch(courierProfileProvider)?.isStoreCourier ?? false;
});

/// Convenience: warehouse IDs for store courier
final courierWarehouseIdsProvider = Provider<List<String>>((ref) {
  return ref.watch(courierProfileProvider)?.warehouseIds ?? [];
});
