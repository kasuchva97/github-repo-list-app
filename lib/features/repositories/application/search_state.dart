import 'package:flutter/foundation.dart';

import '../data/models/repository_summary.dart';
import '../data/models/search_filters.dart';

/// Immutable state of the search screen.
///
/// The screen derives exactly one of these views from it:
/// * [isIdle]        → Home screen (empty search box)
/// * [isLoading]     → full-screen loading indicator (first page)
/// * [error]         → full-screen error with retry (first page failed)
/// * [isEmpty]       → Empty screen (query returned no repositories)
/// * otherwise       → the result list, with a footer that reflects
///                     [isLoadingMore], [loadMoreError] and [hasMore].
@immutable
class SearchState {
  const SearchState({
    this.query = '',
    this.filters = const SearchFilters(),
    this.items = const [],
    this.totalCount = 0,
    this.nextPage = 1,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
  });

  /// The trimmed query whose results are in [items].
  final String query;
  final SearchFilters filters;
  final List<RepositorySummary> items;
  final int totalCount;

  /// The next page to request from the Search API (1-based).
  final int nextPage;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;

  /// Error of the first page. Results are empty when this is set.
  final Object? error;

  /// Error of a subsequent page. Already loaded results are kept.
  final Object? loadMoreError;

  bool get isIdle => query.isEmpty;
  bool get isEmpty => !isIdle && !isLoading && error == null && items.isEmpty;

  bool get canLoadMore =>
      !isIdle &&
      hasMore &&
      !isLoading &&
      !isLoadingMore &&
      error == null &&
      loadMoreError == null;

  SearchState copyWith({
    String? query,
    SearchFilters? filters,
    List<RepositorySummary>? items,
    int? totalCount,
    int? nextPage,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? Function()? error,
    Object? Function()? loadMoreError,
  }) {
    return SearchState(
      query: query ?? this.query,
      filters: filters ?? this.filters,
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      nextPage: nextPage ?? this.nextPage,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error != null ? error() : this.error,
      loadMoreError: loadMoreError != null
          ? loadMoreError()
          : this.loadMoreError,
    );
  }
}
