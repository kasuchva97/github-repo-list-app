import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_repo_list/core/providers.dart';
import 'package:github_repo_list/features/repositories/data/github_repository.dart';
import 'package:github_repo_list/features/repositories/data/models/repository_detail.dart';
import 'package:github_repo_list/features/repositories/data/models/repository_summary.dart';
import 'package:github_repo_list/features/repositories/data/models/search_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

RepositorySummary repo(int id, {String? fullName}) => RepositorySummary(
  id: id,
  fullName: fullName ?? 'owner$id/repo$id',
  ownerAvatarUrl: 'https://avatars.githubusercontent.com/u/$id?v=4',
);

/// Builds a page of [count] repositories with ids starting at [firstId].
SearchPage page({
  required int firstId,
  required int count,
  required int totalCount,
}) => SearchPage(
  totalCount: totalCount,
  items: [for (var i = 0; i < count; i++) repo(firstId + i)],
);

/// In-memory [GitHubRepository] whose responses are scripted per test.
class FakeGitHubRepository implements GitHubRepository {
  /// Called for every search. Return a value, throw, or return a pending
  /// future to simulate a slow request.
  FutureOr<SearchPage> Function(String query, int page) onSearch = (
    query,
    page,
  ) => const SearchPage(totalCount: 0, items: []);

  FutureOr<RepositoryDetail> Function(String fullName) onFetch = (fullName) =>
      throw UnimplementedError();

  final List<(String, int)> searchCalls = [];
  final List<String> fetchCalls = [];

  @override
  Future<SearchPage> searchRepositories(
    String query, {
    required int page,
    int perPage = GitHubRepository.defaultPageSize,
  }) async {
    searchCalls.add((query, page));
    return onSearch(query, page);
  }

  @override
  Future<RepositoryDetail> fetchRepository(String fullName) async {
    fetchCalls.add(fullName);
    return onFetch(fullName);
  }
}

/// Creates a container wired to fakes, the way `main()` wires real services.
Future<ProviderContainer> createContainer({
  required FakeGitHubRepository github,
  Map<String, Object> prefsValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      gitHubRepositoryProvider.overrideWithValue(github),
    ],
  );
  return container;
}
