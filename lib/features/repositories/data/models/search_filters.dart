import 'package:flutter/foundation.dart';

/// Sort orders supported by the Search API (`sort` + `order` parameters).
enum SearchSort {
  bestMatch('Best match', null),
  stars('Most stars', 'stars'),
  forks('Most forks', 'forks'),
  updated('Recently updated', 'updated');

  const SearchSort(this.label, this.apiValue);

  final String label;

  /// Value of the `sort` query parameter; `null` means GitHub's default
  /// "best match" ranking (the parameter must be omitted).
  final String? apiValue;
}

/// Languages offered as quick filters. The value is used verbatim in the
/// `language:` search qualifier.
const List<String> filterLanguages = [
  'Dart',
  'Kotlin',
  'Swift',
  'TypeScript',
  'JavaScript',
  'Python',
  'Go',
  'Rust',
];

/// User-selected search refinements.
@immutable
class SearchFilters {
  const SearchFilters({this.sort = SearchSort.bestMatch, this.language});

  final SearchSort sort;
  final String? language;

  bool get isDefault => sort == SearchSort.bestMatch && language == null;

  SearchFilters copyWith({SearchSort? sort, String? Function()? language}) =>
      SearchFilters(
        sort: sort ?? this.sort,
        language: language != null ? language() : this.language,
      );

  /// Builds the `q` parameter: the keyword plus an optional
  /// `language:` qualifier.
  String buildQuery(String keyword) {
    final lang = language;
    if (lang == null) return keyword;
    return '$keyword language:${lang.contains(' ') ? '"$lang"' : lang}';
  }

  @override
  bool operator ==(Object other) =>
      other is SearchFilters &&
      other.sort == sort &&
      other.language == language;

  @override
  int get hashCode => Object.hash(sort, language);
}
