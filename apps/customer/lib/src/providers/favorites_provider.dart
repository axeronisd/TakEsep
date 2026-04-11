import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

/// Provider for user's favorite products (server-synced)
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier();
});

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await _supabase
          .from('favorites')
          .select('product_id')
          .eq('user_id', userId);

      final ids = (data as List)
          .map((e) => e['product_id'] as String)
          .toSet();

      state = ids;
      debugPrint('❤️ Loaded ${ids.length} favorites');
    } catch (e) {
      debugPrint('⚠️ Favorites load: $e');
      // Table might not exist yet — create it on first toggle
    }
  }

  bool isFavorite(String productId) => state.contains(productId);

  Future<void> toggle(String productId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final wasFavorite = state.contains(productId);

    // Optimistic update
    if (wasFavorite) {
      state = {...state}..remove(productId);
    } else {
      state = {...state, productId};
    }

    try {
      if (wasFavorite) {
        await _supabase
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('product_id', productId);
        debugPrint('💔 Removed from favorites: $productId');
      } else {
        await _supabase.from('favorites').insert({
          'user_id': userId,
          'product_id': productId,
        });
        debugPrint('❤️ Added to favorites: $productId');
      }
    } catch (e) {
      debugPrint('⚠️ Favorites toggle: $e');
      // Revert on error
      if (wasFavorite) {
        state = {...state, productId};
      } else {
        state = {...state}..remove(productId);
      }
    }
  }
}
