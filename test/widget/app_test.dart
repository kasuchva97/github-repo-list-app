import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_repo_list/app.dart';
import 'package:github_repo_list/core/network/api_exception.dart';
import 'package:github_repo_list/core/providers.dart';
import 'package:github_repo_list/features/favorites/data/favorites_storage.dart';
import 'package:github_repo_list/features/repositories/application/search_controller.dart';
import 'package:github_repo_list/features/repositories/data/models/repository_detail.dart';
import 'package:github_repo_list/features/repositories/data/models/search_page.dart';
import 'package:material_ui/material_ui.dart';
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
}
