import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// Most recent successful searches, newest first, persisted across launches.
final searchHistoryProvider =
    NotifierProvider<SearchHistoryController, List<String>>(
      SearchHistoryController.new,
    );

class SearchHistoryController extends Notifier<List<String>> {
  static const String storageKey = 'recent_searches_v1';
  static const int maxEntries = 8;

  @override
  List<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return List.unmodifiable(prefs.getStringList(storageKey) ?? const []);
  }

  /// Moves [query] to the top (case-insensitive de-duplication).
  Future<void> record(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final next = [
      trimmed,
      ...state.where((q) => q.toLowerCase() != trimmed.toLowerCase()),
    ].take(maxEntries).toList();
    await _commit(next);
  }

  Future<void> remove(String query) =>
      _commit(state.where((q) => q != query).toList());

  Future<void> clear() => _commit(const []);

  Future<void> _commit(List<String> next) async {
    state = List.unmodifiable(next);
    // History is a convenience: a failed write must never surface as an error.
    try {
      await ref.read(sharedPreferencesProvider).setStringList(storageKey, next);
    } on Object {
      // Ignored on purpose.
    }
  }
}
