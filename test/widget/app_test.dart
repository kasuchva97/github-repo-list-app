import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_repo_list/app.dart';
import 'package:github_repo_list/core/network/api_exception.dart';
import 'package:github_repo_list/core/providers.dart';
import 'package:github_repo_list/features/favorites/data/favorites_storage.dart';
import 'package:github_repo_list/features/repositories/application/search_controller.dart';
import 'package:github_repo_list/features/repositories/data/models/repository_detail.dart';
import 'package:github_repo_list/features/repositories/data/models/search_filters.dart';
import 'package:github_repo_list/features/repositories/data/models/search_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeGitHubRepository github;

  setUp(() => github = FakeGitHubRepository());

  Future<SharedPreferences> pumpApp(
    WidgetTester tester, {
    Map<String, Object> prefsValues = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          gitHubRepositoryProvider.overrideWithValue(github),
        ],
        child: const GitHubRepoListApp(),
      ),
    );
    return prefs;
  }

  Future<void> typeQuery(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('search-field')), text);
    await tester.pump(searchDebounce);
    await tester.pump();
  }

  Finder starOf(int id) => find.byKey(ValueKey('favorite-$id'));

  bool isStarred(WidgetTester tester, int id) =>
      tester.widget<IconButton>(starOf(id).hitTestable()).isSelected ?? false;

  testWidgets('shows Home, then loading, then results', (tester) async {
    final response = Completer<SearchPage>();
    github.onSearch = (q, p) => response.future;
    await pumpApp(tester);

    expect(find.byKey(const Key('search-home')), findsOneWidget);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Star'), findsOneWidget);

    await typeQuery(tester, 'flutter');
    expect(find.byKey(const Key('search-loading')), findsOneWidget);

    response.complete(page(firstId: 1, count: 3, totalCount: 3));
    await tester.pumpAndSettle();

    expect(find.text('owner1/repo1'), findsOneWidget);
    expect(find.text('owner3/repo3'), findsOneWidget);
    expect(find.byKey(const Key('end-of-results')), findsOneWidget);
  });

  testWidgets('shows the Empty screen when nothing matches', (tester) async {
    github.onSearch = (q, p) => const SearchPage(totalCount: 0, items: []);
    await pumpApp(tester);

    await typeQuery(tester, 'qwertyuiop-no-such-repo');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-empty')), findsOneWidget);
  });

  testWidgets('shows an error with Retry that recovers', (tester) async {
    var fail = true;
    github.onSearch = (q, p) {
      if (fail) throw const NetworkException('offline');
      return page(firstId: 1, count: 1, totalCount: 1);
    };
    await pumpApp(tester);

    await typeQuery(tester, 'flutter');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-error')), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('owner1/repo1'), findsOneWidget);
  });

  testWidgets('clearing the search box returns to Home', (tester) async {
    github.onSearch = (q, p) => page(firstId: 1, count: 1, totalCount: 1);
    await pumpApp(tester);

    await typeQuery(tester, 'flutter');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-home')), findsOneWidget);
  });

  testWidgets('scrolling to the end loads the next page', (tester) async {
    github.onSearch = (q, p) =>
        page(firstId: (p - 1) * 30 + 1, count: 30, totalCount: 60);
    await pumpApp(tester);

    await typeQuery(tester, 'flutter');
    await tester.pumpAndSettle();
    expect(github.searchCalls, [('flutter', 1)]);

    await tester.scrollUntilVisible(
      find.text('owner60/repo60'),
      500,
      scrollable: find.descendant(
        of: find.byKey(const Key('search-results')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(github.searchCalls, [('flutter', 1), ('flutter', 2)]);
    expect(find.text('owner60/repo60'), findsOneWidget);
  });

  testWidgets(
    'starring in the list syncs the detail screen, the Star tab and storage',
    (tester) async {
      github.onSearch = (q, p) => page(firstId: 1, count: 2, totalCount: 2);
      github.onFetch = (fullName) => RepositoryDetail(
        id: 1,
        fullName: fullName,
        ownerAvatarUrl: '',
        subscribersCount: 4321,
      );
      final prefs = await pumpApp(tester);

      await typeQuery(tester, 'flutter');
      await tester.pumpAndSettle();

      // Star from the list.
      expect(isStarred(tester, 1), isFalse);
      await tester.tap(starOf(1));
      await tester.pump();
      expect(isStarred(tester, 1), isTrue);
      expect(
        prefs.getString(SharedPreferencesFavoritesStorage.storageKey),
        contains('"full_name":"owner1/repo1"'),
      );

      // Detail screen shows the same state and subscribers_count.
      await tester.tap(find.text('owner1/repo1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-full-name')), findsOneWidget);
      expect(find.text('4,321'), findsOneWidget);
      expect(isStarred(tester, 1), isTrue);

      // Un-star in detail; going back shows the updated state in the list.
      await tester.tap(starOf(1));
      await tester.pump();
      expect(isStarred(tester, 1), isFalse);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(isStarred(tester, 1), isFalse);

      // Star repo 2 and confirm it appears in the Star tab.
      await tester.tap(starOf(2));
      await tester.pump();
      await tester.tap(find.text('Star'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('favorites-list')), findsOneWidget);
      expect(find.text('owner2/repo2'), findsOneWidget);
      expect(find.text('owner1/repo1'), findsNothing);

      // Remove from the Star tab; the search list reflects it immediately.
      await tester.tap(starOf(2).hitTestable());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('favorites-empty')), findsOneWidget);
      expect(
        prefs.getString(SharedPreferencesFavoritesStorage.storageKey),
        '[]',
      );

      await tester.tap(find.text('Search').last);
      await tester.pumpAndSettle();
      expect(isStarred(tester, 2), isFalse);
    },
  );

  testWidgets('favorites persisted earlier are shown on launch', (
    tester,
  ) async {
    await pumpApp(
      tester,
      prefsValues: {
        SharedPreferencesFavoritesStorage.storageKey:
            '[{"id":7,"full_name":"dart-lang/sdk","avatar_url":""}]',
      },
    );

    await tester.tap(find.text('Star'));
    await tester.pumpAndSettle();
    expect(find.text('dart-lang/sdk'), findsOneWidget);
  });

  testWidgets('undo after removing a favorite restores it', (tester) async {
    await pumpApp(
      tester,
      prefsValues: {
        SharedPreferencesFavoritesStorage.storageKey:
            '[{"id":7,"full_name":"dart-lang/sdk","avatar_url":""}]',
      },
    );
    await tester.tap(find.text('Star'));
    await tester.pumpAndSettle();

    await tester.tap(starOf(7).hitTestable());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('favorites-empty')), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('dart-lang/sdk'), findsOneWidget);
  });

  testWidgets('detail screen shows an error with Retry', (tester) async {
    var fail = true;
    github.onSearch = (q, p) => page(firstId: 1, count: 1, totalCount: 1);
    github.onFetch = (fullName) {
      if (fail) throw const NotFoundException('Not Found');
      return RepositoryDetail(
        id: 1,
        fullName: fullName,
        ownerAvatarUrl: '',
        subscribersCount: 12,
      );
    };
    await pumpApp(tester);
    await typeQuery(tester, 'flutter');
    await tester.pumpAndSettle();

    await tester.tap(find.text('owner1/repo1'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-error')), findsOneWidget);
    // The header is still shown from the list data.
    expect(find.byKey(const Key('detail-full-name')), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('Home shows suggestions, then recent searches after a search', (
    tester,
  ) async {
    github.onSearch = (q, p) => page(firstId: 1, count: 2, totalCount: 2);
    await pumpApp(tester);

    expect(find.byKey(const Key('suggestion-flutter')), findsOneWidget);
    expect(find.text('Recent searches'), findsNothing);

    await typeQuery(tester, 'riverpod');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.byKey(const ValueKey('recent-riverpod')), findsOneWidget);

    // Tapping a recent search fills the box and searches again.
    await tester.tap(find.byKey(const ValueKey('recent-riverpod')));
    await tester.pumpAndSettle();
    expect(find.text('owner1/repo1'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('search-field')))
          .controller!
          .text,
      'riverpod',
    );
  });

  testWidgets('tapping a suggestion searches for it', (tester) async {
    github.onSearch = (q, p) => page(firstId: 1, count: 1, totalCount: 1);
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('suggestion-dart')));
    await tester.pumpAndSettle();

    expect(github.searchCalls.first, ('dart', 1));
    expect(find.text('owner1/repo1'), findsOneWidget);
  });

  // Queries of first-page requests (later pages load automatically when the
  // short fake result list leaves the footer in view).
  List<String> firstPageQueries() => [
    for (final (query, page) in github.searchCalls)
      if (page == 1) query,
  ];

  testWidgets('sort menu and language chips refine the search', (tester) async {
    github.onSearch = (q, p) => page(firstId: 1, count: 2, totalCount: 1234);
    await pumpApp(tester);
    await typeQuery(tester, 'flutter');
    await tester.pumpAndSettle();

    expect(find.text('1,234 repositories'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<SearchSort>, 'Most stars'),
    );
    await tester.pumpAndSettle();
    expect(github.sortCalls.last, SearchSort.stars);

    await tester.tap(find.byKey(const ValueKey('lang-Dart')));
    await tester.pumpAndSettle();
    expect(firstPageQueries().last, 'flutter language:Dart');
    expect(github.sortCalls.last, SearchSort.stars);

    // Tapping the selected chip again removes the filter.
    await tester.tap(find.byKey(const ValueKey('lang-Dart')));
    await tester.pumpAndSettle();
    expect(firstPageQueries().last, 'flutter');
  });

  testWidgets('empty results with filters offer to reset them', (tester) async {
    github.onSearch = (q, p) => q.contains('language:')
        ? const SearchPage(totalCount: 0, items: [])
        : page(firstId: 1, count: 1, totalCount: 1);
    await pumpApp(tester);
    await typeQuery(tester, 'flutter');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('lang-Dart')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reset-filters')));
    await tester.pumpAndSettle();
    expect(find.text('owner1/repo1'), findsOneWidget);
  });

  testWidgets('detail shows topics, license and last update; topic jumps '
      'to Search', (tester) async {
    github.onSearch = (q, p) => page(firstId: 1, count: 1, totalCount: 1);
    github.onFetch = (fullName) => RepositoryDetail(
      id: 1,
      fullName: fullName,
      ownerAvatarUrl: '',
      subscribersCount: 5,
      language: 'Dart',
      licenseName: 'MIT',
      topics: const ['widgets', 'mobile'],
      pushedAt: DateTime.now().subtract(const Duration(days: 3)),
    );
    await pumpApp(tester);
    await typeQuery(tester, 'flutter');
    await tester.pumpAndSettle();

    await tester.tap(find.text('owner1/repo1'));
    await tester.pumpAndSettle();
    expect(find.text('MIT'), findsOneWidget);
    expect(find.text('Updated 3 days ago'), findsOneWidget);
    expect(find.text('widgets'), findsOneWidget);

    await tester.ensureVisible(find.text('widgets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('widgets'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-full-name')), findsNothing);
    expect(github.searchCalls.last.$1, 'widgets');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('search-field')))
          .controller!
          .text,
      'widgets',
    );
  });

  testWidgets('copy link button copies the GitHub URL', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    github.onSearch = (q, p) => page(firstId: 1, count: 1, totalCount: 1);
    github.onFetch = (fullName) => RepositoryDetail(
      id: 1,
      fullName: fullName,
      ownerAvatarUrl: '',
      subscribersCount: 1,
    );
    await pumpApp(tester);
    await typeQuery(tester, 'flutter');
    await tester.pumpAndSettle();
    await tester.tap(find.text('owner1/repo1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('copy-link')));
    await tester.pump();

    expect(copied, 'https://github.com/owner1/repo1');
    expect(find.text('Link copied'), findsOneWidget);
  });

  testWidgets('favorites can be filtered and swiped away', (tester) async {
    final entries = [
      for (var i = 1; i <= 6; i++)
        '{"id":$i,"full_name":"${i.isEven ? 'dart-lang' : 'flutter'}/r$i",'
            '"avatar_url":""}',
    ];
    await pumpApp(
      tester,
      prefsValues: {
        SharedPreferencesFavoritesStorage.storageKey: '[${entries.join(',')}]',
      },
    );
    await tester.tap(find.text('Star'));
    await tester.pumpAndSettle();

    expect(find.text('Favorites (6)'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('favorites-filter')), 'dart');
    await tester.pumpAndSettle();
    expect(find.text('dart-lang/r2'), findsOneWidget);
    expect(find.text('flutter/r1'), findsNothing);

    await tester.enterText(find.byKey(const Key('favorites-filter')), 'nope');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('favorites-no-match')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('favorites-filter')), '');
    await tester.pumpAndSettle();
    await tester.drag(find.text('flutter/r1'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('flutter/r1'), findsNothing);
    expect(find.text('Favorites (5)'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('flutter/r1'), findsOneWidget);
  });
}
