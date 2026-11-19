import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../repositories/data/models/repository_summary.dart';
import '../data/favorites_storage.dart';

/// The single source of truth for favorites.
///
/// Every screen (search list, detail, star list) reads from this notifier,
/// so a change made anywhere is reflected everywhere on the next frame.
final favoritesProvider =
    NotifierProvider<FavoritesController, List<RepositorySummary>>(
      FavoritesController.new,
    );

/// Whether the repository with the given id is a favorite.
///
/// Uses `select` so a tile only rebuilds when *its own* star state changes,
/// not whenever any favorite is added or removed.
final isFavoriteProvider = Provider.family<bool, int>(
  (ref, id) => ref.watch(
    favoritesProvider.select((favorites) => favorites.any((r) => r.id == id)),
  ),
);

class FavoritesController extends Notifier<List<RepositorySummary>> {
  late FavoritesStorage _storage;

  @override
  List<RepositorySummary> build() {
    _storage = ref.watch(favoritesStorageProvider);
    return _storage.load();
  }

  bool isFavorite(int id) => state.any((r) => r.id == id);

  /// Adds [repository] (at the top) or removes it, then persists.
  ///
  /// Returns `true` when the repository is a favorite afterwards.
  Future<bool> toggle(RepositorySummary repository) async {
    if (isFavorite(repository.id)) {
      await remove(repository.id);
      return false;
    }
    await add(repository);
    return true;
  }

  /// Adds [repository]. [index] lets an "undo" put it back where it was.
  Future<void> add(RepositorySummary repository, {int index = 0}) async {
    if (isFavorite(repository.id)) return;
    // Persist only the minimal identity so stale extras are never stored.
    final favorite = RepositorySummary(
      id: repository.id,
      fullName: repository.fullName,
      ownerAvatarUrl: repository.ownerAvatarUrl,
    );
    final next = [...state]..insert(index.clamp(0, state.length), favorite);
    await _commit(next);
  }

  /// Removes the repository with [id]. Returns its previous index, or -1.
  Future<int> remove(int id) async {
    final index = state.indexWhere((r) => r.id == id);
    if (index == -1) return -1;
    final next = [...state]..removeAt(index);
    await _commit(next);
    return index;
  }

  /// Optimistically updates the UI, then writes to disk. If the write fails
  /// the previous state is restored so the UI never lies about what is saved.
  Future<void> _commit(List<RepositorySummary> next) async {
    final previous = state;
    state = List.unmodifiable(next);
    bool saved;
    try {
      saved = await _storage.save(state);
    } on Object catch (e) {
      debugPrint('Saving favorites failed: $e');
      saved = false;
    }
    if (!saved) {
      if (ref.mounted) state = previous;
      throw const FavoritesPersistenceException();
    }
  }
}

class FavoritesPersistenceException implements Exception {
  const FavoritesPersistenceException();

  @override
  String toString() => 'Could not save favorites.';
}
