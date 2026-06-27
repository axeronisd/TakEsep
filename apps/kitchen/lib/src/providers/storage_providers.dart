import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/storage_repository.dart';

/// Provides the instance of StorageRepository
final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return StorageRepository(Supabase.instance.client);
});
