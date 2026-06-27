import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/inventory_repository.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository();
});
