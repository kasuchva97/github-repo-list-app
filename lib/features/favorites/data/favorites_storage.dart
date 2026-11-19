import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/data/models/repository_summary.dart';

/// Persistence contract for favorite repositories.
abstract interface class FavoritesStorage {
  /// Returns the stored favorites, most recently added first.
  List<RepositorySummary> load();

  /// Replaces the stored favorites. Returns `false` if the write failed.
  Future<bool> save(List<RepositorySummary> favorites);
}

/// Stores favorites in `shared_preferences` as a single JSON array:
///
/// ```json
/// [{"id": 1, "full_name": "flutter/flutter", "avatar_url": "https://..."}]
/// ```
///
/// One key (rather than one key per repo) keeps writes atomic and preserves
/// ordering. The key is versioned so the format can evolve safely.
class SharedPreferencesFavoritesStorage implements FavoritesStorage {
  SharedPreferencesFavoritesStorage(this._prefs);

  static const String storageKey = 'favorite_repositories_v1';

  final SharedPreferences _prefs;

  @override
  List<RepositorySummary> load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final result = <RepositorySummary>[];
      final seen = <int>{};
      for (final entry in decoded) {
        // Skip individual corrupt entries instead of losing every favorite.
        try {
          final repo = RepositorySummary.fromFavoriteJson(
            entry as Map<String, dynamic>,
          );
          if (seen.add(repo.id)) result.add(repo);
        } on Object catch (e) {
          debugPrint('Skipping corrupt favorite entry: $e');
        }
      }
      return List.unmodifiable(result);
    } on FormatException catch (e) {
      debugPrint('Discarding unreadable favorites: $e');
      return const [];
    }
  }

  @override
  Future<bool> save(List<RepositorySummary> favorites) {
    final encoded = jsonEncode(
      favorites.map((repo) => repo.toFavoriteJson()).toList(),
    );
    return _prefs.setString(storageKey, encoded);
  }
}
