import 'package:flutter/foundation.dart';

import 'repository_summary.dart';

/// One page of the Repository Search API.
@immutable
class SearchPage {
  const SearchPage({
    required this.totalCount,
    required this.items,
    this.incompleteResults = false,
  });

  factory SearchPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return SearchPage(
      totalCount: json['total_count'] as int? ?? 0,
      incompleteResults: json['incomplete_results'] as bool? ?? false,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(RepositorySummary.fromSearchJson)
          .toList(growable: false),
    );
  }

  final int totalCount;
  final bool incompleteResults;
  final List<RepositorySummary> items;
}
