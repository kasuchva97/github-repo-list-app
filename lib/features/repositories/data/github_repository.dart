import '../../../core/network/api_exception.dart';
import '../../../core/network/github_http_client.dart';
import 'models/repository_detail.dart';
import 'models/search_filters.dart';
import 'models/search_page.dart';

/// Data source for GitHub repositories.
///
/// Abstract so that the application layer (and tests) depend on this
/// contract rather than on HTTP.
abstract interface class GitHubRepository {
  /// GitHub only serves the first 1,000 results of any search.
  static const int maxSearchResults = 1000;

  /// Default page size used by the search screen.
  static const int defaultPageSize = 30;

  /// `GET /search/repositories?q={query}&page={page}&per_page={perPage}`
  Future<SearchPage> searchRepositories(
    String query, {
    required int page,
    int perPage = defaultPageSize,
    SearchSort sort = SearchSort.bestMatch,
  });

  /// `GET /repos/{owner}/{repo}`
  Future<RepositoryDetail> fetchRepository(String fullName);
}

class GitHubRepositoryImpl implements GitHubRepository {
  GitHubRepositoryImpl(this._client);

  final GitHubHttpClient _client;

  static final RegExp _fullNamePattern = RegExp(
    r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$',
  );

  @override
  Future<SearchPage> searchRepositories(
    String query, {
    required int page,
    int perPage = GitHubRepository.defaultPageSize,
    SearchSort sort = SearchSort.bestMatch,
  }) async {
    assert(page >= 1, 'GitHub pages are 1-based');
    final json = await _client.getJson(
      '/search/repositories',
      queryParameters: {
        'q': query,
        'page': '$page',
        'per_page': '$perPage',
        if (sort.apiValue != null) ...{'sort': sort.apiValue!, 'order': 'desc'},
      },
    );
    return _parse(() => SearchPage.fromJson(json));
  }

  @override
  Future<RepositoryDetail> fetchRepository(String fullName) async {
    // GitHub owner and repository names only contain `[A-Za-z0-9._-]`, so a
    // strict check is enough to keep the path well-formed.
    if (!_fullNamePattern.hasMatch(fullName)) {
      throw ValidationException('Invalid repository name: $fullName');
    }
    final json = await _client.getJson('/repos/$fullName');
    return _parse(() => RepositoryDetail.fromJson(json));
  }

  /// Converts type errors from unexpected payloads into [ParseException].
  T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on TypeError catch (e) {
      throw ParseException('Unexpected response shape: $e');
    }
  }
}
