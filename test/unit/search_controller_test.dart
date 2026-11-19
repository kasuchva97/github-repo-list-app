import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_repo_list/core/network/api_exception.dart';
import 'package:github_repo_list/features/repositories/application/search_controller.dart';
import 'package:github_repo_list/features/repositories/data/models/search_page.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeGitHubRepository github;
  late ProviderContainer container;

  setUp(() async {
    github = FakeGitHubRepository();
    container = await createContainer(github: github);
    addTearDown(container.dispose);
    // Keep the notifier alive for the whole test.
    container.listen(repositorySearchProvider, (_, _) {});
  });

  RepositorySearchController controller() =>
      container.read(repositorySearchProvider.notifier);

  test('initial state is the Home (idle) state', () {
    final state = container.read(repositorySearchProvider);
    expect(state.isIdle, isTrue);
    expect(state.items, isEmpty);
  });

  test('search loads the first page', () async {
    github.onSearch = (q, p) => page(firstId: 1, count: 30, totalCount: 75);

    final future = controller().search('  flutter ');
    expect(container.read(repositorySearchProvider).isLoading, isTrue);
    await future;

    final state = container.read(repositorySearchProvider);
    expect(github.searchCalls, [('flutter', 1)]);
    expect(state.query, 'flutter');
    expect(state.items, hasLength(30));
    expect(state.hasMore, isTrue);
    expect(state.nextPage, 2);
  });

  test('no results yields the Empty state', () async {
    github.onSearch = (q, p) => const SearchPage(totalCount: 0, items: []);
    await controller().search('zzzzzz-nothing');

    final state = container.read(repositorySearchProvider);
    expect(state.isEmpty, isTrue);
    expect(state.hasMore, isFalse);
  });

  test('loadMore appends pages until total_count is reached', () async {
    github.onSearch = (q, p) =>
        page(firstId: (p - 1) * 30 + 1, count: p < 3 ? 30 : 15, totalCount: 75);

    await controller().search('flutter');
    await controller().loadMore();
    await controller().loadMore();
    await controller().loadMore(); // Nothing left: must not request page 4.

    final state = container.read(repositorySearchProvider);
    expect(state.items, hasLength(75));
    expect(state.hasMore, isFalse);
    expect(github.searchCalls.map((c) => c.$2), [1, 2, 3]);
  });

  test('concurrent loadMore calls request the next page only once', () async {
    final pending = Completer<SearchPage>();
    github.onSearch = (q, p) =>
        p == 1 ? page(firstId: 1, count: 30, totalCount: 100) : pending.future;

    await controller().search('flutter');
    unawaited(controller().loadMore());
    unawaited(controller().loadMore());
    unawaited(controller().loadMore());
    pending.complete(page(firstId: 31, count: 30, totalCount: 100));
    await pumpEventQueue();

    expect(github.searchCalls, [('flutter', 1), ('flutter', 2)]);
    expect(container.read(repositorySearchProvider).items, hasLength(60));
  });

  test(
    'a slow response for an old query never overwrites a newer one',
    () async {
      final slow = Completer<SearchPage>();
      github.onSearch = (q, p) => q == 'old'
          ? slow.future
          : page(firstId: 100, count: 1, totalCount: 1);

      final oldSearch = controller().search('old');
      await controller().search('new');
      slow.complete(page(firstId: 1, count: 30, totalCount: 30));
      await oldSearch;

      final state = container.read(repositorySearchProvider);
      expect(state.query, 'new');
      expect(state.items.single.id, 100);
    },
  );

  test('duplicate repositories across pages are dropped', () async {
    github.onSearch = (q, p) => p == 1
        ? page(firstId: 1, count: 30, totalCount: 60)
        : page(firstId: 29, count: 30, totalCount: 60); // overlaps 29, 30

    await controller().search('flutter');
    await controller().loadMore();

    final ids = container.read(repositorySearchProvider).items.map((r) => r.id);
    expect(ids.toSet().length, ids.length);
    expect(ids, hasLength(58));
  });

  test('first page error is exposed and retry recovers', () async {
    var fail = true;
    github.onSearch = (q, p) {
      if (fail) throw const RateLimitException('limit');
      return page(firstId: 1, count: 5, totalCount: 5);
    };

    await controller().search('flutter');
    expect(
      container.read(repositorySearchProvider).error,
      isA<RateLimitException>(),
    );

    fail = false;
    await controller().retry();
    final state = container.read(repositorySearchProvider);
    expect(state.error, isNull);
    expect(state.items, hasLength(5));
  });

  test('next page error keeps loaded items and can be retried', () async {
    var failPage2 = true;
    github.onSearch = (q, p) {
      if (p == 2 && failPage2) {
        throw const NetworkException('offline');
      }
      return page(firstId: (p - 1) * 30 + 1, count: 30, totalCount: 60);
    };

    await controller().search('flutter');
    await controller().loadMore();
    var state = container.read(repositorySearchProvider);
    expect(state.items, hasLength(30));
    expect(state.loadMoreError, isA<NetworkException>());
    expect(state.canLoadMore, isFalse);

    failPage2 = false;
    await controller().retry();
    state = container.read(repositorySearchProvider);
    expect(state.items, hasLength(60));
    expect(state.loadMoreError, isNull);
  });

  test('pagination stops at GitHub\'s 1,000 result cap', () async {
    github.onSearch = (q, p) =>
        page(firstId: (p - 1) * 100 + 1, count: 100, totalCount: 500000);

    await controller().search('a');
    for (var i = 0; i < 12; i++) {
      await controller().loadMore();
    }

    final state = container.read(repositorySearchProvider);
    expect(state.items, hasLength(1000));
    expect(state.hasMore, isFalse);
  });

  test('a 422 on a later page ends pagination quietly', () async {
    github.onSearch = (q, p) {
      if (p == 2) throw const ValidationException('Only the first 1000');
      return page(firstId: 1, count: 30, totalCount: 5000);
    };

    await controller().search('flutter');
    await controller().loadMore();

    final state = container.read(repositorySearchProvider);
    expect(state.hasMore, isFalse);
    expect(state.loadMoreError, isNull);
  });

  test(
    'clearing the query returns to Home and ignores in-flight results',
    () async {
      final slow = Completer<SearchPage>();
      github.onSearch = (q, p) => slow.future;

      final search = controller().search('flutter');
      controller().onQueryChanged('   ');
      slow.complete(page(firstId: 1, count: 30, totalCount: 30));
      await search;

      expect(container.read(repositorySearchProvider).isIdle, isTrue);
    },
  );

  test('onQueryChanged debounces keystrokes into one request', () async {
    github.onSearch = (q, p) => page(firstId: 1, count: 1, totalCount: 1);

    controller()
      ..onQueryChanged('f')
      ..onQueryChanged('fl')
      ..onQueryChanged('flutter');
    expect(github.searchCalls, isEmpty);

    await Future<void>.delayed(
      searchDebounce + const Duration(milliseconds: 50),
    );
    expect(github.searchCalls, [('flutter', 1)]);
  });
}
