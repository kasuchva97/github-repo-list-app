import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_repo_list/core/format.dart';
import 'package:github_repo_list/core/providers.dart';
import 'package:github_repo_list/features/history/application/search_history_controller.dart';
import 'package:github_repo_list/features/repositories/application/search_controller.dart';
import 'package:github_repo_list/features/repositories/data/models/search_filters.dart';

import '../helpers/fakes.dart';

void main() {
  group('SearchFilters', () {
    test('buildQuery appends a language qualifier', () {
      expect(const SearchFilters().buildQuery('flutter'), 'flutter');
      expect(
        const SearchFilters(language: 'Dart').buildQuery('flutter ui'),
        'flutter ui language:Dart',
      );
      expect(
        const SearchFilters(language: 'Jupyter Notebook').buildQuery('x'),
        'x language:"Jupyter Notebook"',
      );
    });

    test('isDefault and equality', () {
      expect(const SearchFilters().isDefault, isTrue);
      expect(const SearchFilters(sort: SearchSort.stars).isDefault, isFalse);
      expect(
        const SearchFilters(language: 'Go'),
        const SearchFilters(language: 'Go'),
      );
    });
  });

  group('search with filters', () {
    late FakeGitHubRepository github;
    late ProviderContainer container;

    setUp(() async {
      github = FakeGitHubRepository()
        ..onSearch = (q, p) => page(firstId: 1, count: 3, totalCount: 3);
      container = await createContainer(github: github);
      addTearDown(container.dispose);
      container.listen(repositorySearchProvider, (_, _) {});
    });

    RepositorySearchController controller() =>
        container.read(repositorySearchProvider.notifier);

    test('changing sort or language re-runs the search', () async {
      await controller().search('flutter');
      await controller().setFilters(
        const SearchFilters(sort: SearchSort.stars, language: 'Dart'),
      );

      expect(github.searchCalls.last, ('flutter language:Dart', 1));
      expect(github.sortCalls.last, SearchSort.stars);
      expect(container.read(repositorySearchProvider).filters.language, 'Dart');
    });

    test('filters apply to later pages too', () async {
      github.onSearch = (q, p) =>
          page(firstId: (p - 1) * 30 + 1, count: 30, totalCount: 60);
      await controller().setFilters(const SearchFilters(language: 'Go'));
      await controller().search('cli');
      await controller().loadMore();

      expect(github.searchCalls, [
        ('cli language:Go', 1),
        ('cli language:Go', 2),
      ]);
    });

    test('filters survive clearing the search', () async {
      await controller().setFilters(const SearchFilters(language: 'Rust'));
      await controller().search('x');
      controller().clear();
      expect(container.read(repositorySearchProvider).filters.language, 'Rust');
    });
  });

  group('search history', () {
    late FakeGitHubRepository github;
    late ProviderContainer container;

    Future<void> setUpContainer([Map<String, Object> prefs = const {}]) async {
      github = FakeGitHubRepository()
        ..onSearch = (q, p) => page(firstId: 1, count: 1, totalCount: 1);
      container = await createContainer(github: github, prefsValues: prefs);
      addTearDown(container.dispose);
      container.listen(repositorySearchProvider, (_, _) {});
    }

    test(
      'successful searches are recorded newest first, without duplicates',
      () async {
        await setUpContainer();
        final search = container.read(repositorySearchProvider.notifier);
        await search.search('flutter');
        await search.search('dart');
        await search.search('Flutter', force: true);

        expect(container.read(searchHistoryProvider), ['Flutter', 'dart']);
      },
    );

    test('empty results are not recorded', () async {
      await setUpContainer();
      github.onSearch = (q, p) => page(firstId: 1, count: 0, totalCount: 0);
      await container.read(repositorySearchProvider.notifier).search('zzz');
      expect(container.read(searchHistoryProvider), isEmpty);
    });

    test('history is capped, removable, clearable and persisted', () async {
      await setUpContainer();
      final history = container.read(searchHistoryProvider.notifier);
      for (var i = 0; i < 12; i++) {
        await history.record('q$i');
      }
      expect(
        container.read(searchHistoryProvider),
        hasLength(SearchHistoryController.maxEntries),
      );
      expect(container.read(searchHistoryProvider).first, 'q11');

      final stored = container
          .read(sharedPreferencesProvider)
          .getStringList(SearchHistoryController.storageKey);
      expect(stored, container.read(searchHistoryProvider));

      await history.remove('q11');
      expect(container.read(searchHistoryProvider), isNot(contains('q11')));
      await history.clear();
      expect(container.read(searchHistoryProvider), isEmpty);
    });

    test('history is restored on launch', () async {
      await setUpContainer({
        SearchHistoryController.storageKey: ['riverpod', 'dart'],
      });
      expect(container.read(searchHistoryProvider), ['riverpod', 'dart']);
    });
  });

  group('format helpers', () {
    test('compactNumber', () {
      expect(compactNumber(999), '999');
      expect(compactNumber(1000), '1k');
      expect(compactNumber(1234), '1.2k');
      expect(compactNumber(170000), '170k');
      expect(compactNumber(1500000), '1.5M');
    });

    test('withSeparators', () {
      expect(withSeparators(12), '12');
      expect(withSeparators(1234567), '1,234,567');
    });

    test('relativeTime', () {
      final now = DateTime.utc(2026, 11, 19, 12);
      String ago(Duration d) => relativeTime(now.subtract(d), now: now);
      expect(ago(const Duration(seconds: 10)), 'just now');
      expect(ago(const Duration(minutes: 1)), '1 minute ago');
      expect(ago(const Duration(hours: 5)), '5 hours ago');
      expect(ago(const Duration(days: 3)), '3 days ago');
      expect(ago(const Duration(days: 65)), '2 months ago');
      expect(ago(const Duration(days: 800)), '2 years ago');
    });
  });
}
