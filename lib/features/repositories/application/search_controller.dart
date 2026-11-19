import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../data/github_repository.dart';
import '../data/models/repository_summary.dart';
import 'search_state.dart';

/// How long to wait after the last keystroke before searching. GitHub allows
/// only 10 unauthenticated search requests per minute, so debouncing matters.
const Duration searchDebounce = Duration(milliseconds: 450);

final repositorySearchProvider =
    NotifierProvider<RepositorySearchController, SearchState>(
      RepositorySearchController.new,
    );

/// Drives the search screen: debouncing, first-page search and pagination.
///
/// Correctness guarantees:
/// * **No stale results.** Every search bumps [_generation]; a response is
///   applied only if its generation is still current, so a slow response for
///   "flut" can never overwrite the results for "flutter".
/// * **No duplicate page loads.** [loadMore] is a no-op while a page is in
///   flight, after an error, or when the end of results has been reached.
/// * **No duplicated rows.** GitHub's ranking can shift between page
///   requests; items already in the list are filtered out by id.
class RepositorySearchController extends Notifier<SearchState> {
  Timer? _debounce;
  int _generation = 0;

  GitHubRepository get _repository => ref.read(gitHubRepositoryProvider);

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  /// Call on every keystroke; searches once typing pauses.
  void onQueryChanged(String rawQuery) {
    _debounce?.cancel();
    final query = rawQuery.trim();
    if (query.isEmpty) {
      clear();
      return;
    }
    _debounce = Timer(searchDebounce, () => search(query));
  }

  /// Searches immediately (e.g. keyboard "search" action).
  Future<void> search(String rawQuery, {bool force = false}) async {
    _debounce?.cancel();
    final query = rawQuery.trim();
    if (query.isEmpty) {
      clear();
      return;
    }
    // Same query already loaded or loading: nothing to do.
    if (!force && query == state.query && state.error == null) return;

    final generation = ++_generation;
    state = SearchState(query: query, isLoading: true);

    try {
      final next = await _fetchFirstPage(query);
      if (_isCurrent(generation)) state = next;
    } on Object catch (e) {
      if (_isCurrent(generation)) state = SearchState(query: query, error: e);
    }
  }

  /// Pull-to-refresh: reloads the first page of the current query while
  /// keeping the visible results until the new ones arrive.
  ///
  /// Throws if the refresh fails, so the caller can show a message; the
  /// existing results stay on screen.
  Future<void> refresh() async {
    final query = state.query;
    if (query.isEmpty) return;
    final generation = ++_generation;
    // Drop any in-flight page load: its generation is now stale.
    state = state.copyWith(isLoadingMore: false, loadMoreError: () => null);
    final next = await _fetchFirstPage(query);
    if (_isCurrent(generation)) state = next;
  }

  Future<SearchState> _fetchFirstPage(String query) async {
    final page = await _repository.searchRepositories(query, page: 1);
    return SearchState(
      query: query,
      items: List.unmodifiable(_dedupe(const [], page.items)),
      totalCount: page.totalCount,
      nextPage: 2,
      hasMore: _hasMore(loaded: page.items.length, totalCount: page.totalCount),
    );
  }

  /// Loads the next page. Safe to call repeatedly (e.g. from scroll events).
  Future<void> loadMore() async {
    if (!state.canLoadMore) return;

    final generation = _generation;
    final query = state.query;
    final page = state.nextPage;
    state = state.copyWith(isLoadingMore: true, loadMoreError: () => null);

    try {
      final result = await _repository.searchRepositories(query, page: page);
      if (!_isCurrent(generation)) return;

      final items = _dedupe(state.items, result.items);
      state = state.copyWith(
        items: List.unmodifiable(items),
        totalCount: result.totalCount,
        nextPage: page + 1,
        isLoadingMore: false,
        // An empty page means GitHub has nothing more, whatever total_count
        // claims (it is an estimate for large result sets).
        hasMore:
            result.items.isNotEmpty &&
            _hasMore(loaded: items.length, totalCount: result.totalCount),
      );
    } on ValidationException {
      // 422: GitHub refuses pages beyond the first 1,000 results.
      if (!_isCurrent(generation)) return;
      state = state.copyWith(isLoadingMore: false, hasMore: false);
    } on Object catch (e) {
      if (!_isCurrent(generation)) return;
      state = state.copyWith(isLoadingMore: false, loadMoreError: () => e);
    }
  }

  /// Retries whatever failed last (first page or next page).
  Future<void> retry() {
    if (state.error != null) return search(state.query, force: true);
    if (state.loadMoreError != null) {
      state = state.copyWith(loadMoreError: () => null);
      return loadMore();
    }
    return Future.value();
  }

  /// Back to the Home screen; cancels anything in flight.
  void clear() {
    _debounce?.cancel();
    _generation++;
    state = const SearchState();
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  bool _hasMore({required int loaded, required int totalCount}) {
    if (loaded == 0) return false;
    final reachable = math.min(totalCount, GitHubRepository.maxSearchResults);
    return loaded < reachable;
  }

  List<RepositorySummary> _dedupe(
    List<RepositorySummary> existing,
    List<RepositorySummary> incoming,
  ) {
    final ids = existing.map((r) => r.id).toSet();
    return [
      ...existing,
      for (final repo in incoming)
        if (ids.add(repo.id)) repo,
    ];
  }
}
