import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_repo_list/core/providers.dart';
import 'package:github_repo_list/features/favorites/application/favorites_controller.dart';
import 'package:github_repo_list/features/favorites/data/favorites_storage.dart';
import 'package:github_repo_list/features/repositories/data/models/repository_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

void main() {
  late ProviderContainer container;

  Future<void> setUpContainer([Map<String, Object> prefs = const {}]) async {
    container = await createContainer(
      github: FakeGitHubRepository(),
      prefsValues: prefs,
    );
    addTearDown(container.dispose);
  }

  FavoritesController controller() =>
      container.read(favoritesProvider.notifier);

  List<Map<String, dynamic>> stored() {
    final raw = container
        .read(sharedPreferencesProvider)
        .getString(SharedPreferencesFavoritesStorage.storageKey);
    return (jsonDecode(raw!) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  test('starts empty when nothing is stored', () async {
    await setUpContainer();
    expect(container.read(favoritesProvider), isEmpty);
  });

  test(
    'toggle adds a favorite and persists id, full_name and avatar_url',
    () async {
      await setUpContainer();
      const repository = RepositorySummary(
        id: 1,
        fullName: 'flutter/flutter',
        ownerAvatarUrl: 'https://avatars.githubusercontent.com/u/14101776?v=4',
        description: 'not persisted',
        stargazersCount: 170000,
      );

      final isFavorite = await controller().toggle(repository);

      expect(isFavorite, isTrue);
      expect(container.read(favoritesProvider), [repository]);
      expect(container.read(isFavoriteProvider(1)), isTrue);
      expect(stored(), [
        {
          'id': 1,
          'full_name': 'flutter/flutter',
          'avatar_url': 'https://avatars.githubusercontent.com/u/14101776?v=4',
        },
      ]);
    },
  );

  test('toggle twice removes the favorite from state and storage', () async {
    await setUpContainer();
    await controller().toggle(repo(1));
    final isFavorite = await controller().toggle(repo(1));

    expect(isFavorite, isFalse);
    expect(container.read(favoritesProvider), isEmpty);
    expect(container.read(isFavoriteProvider(1)), isFalse);
    expect(stored(), isEmpty);
  });

  test(
    'newest favorite comes first and undo restores the original position',
    () async {
      await setUpContainer();
      await controller().add(repo(1));
      await controller().add(repo(2));
      await controller().add(repo(3));
      expect(container.read(favoritesProvider).map((r) => r.id), [3, 2, 1]);

      final index = await controller().remove(2);
      expect(index, 1);
      await controller().add(repo(2), index: index);
      expect(container.read(favoritesProvider).map((r) => r.id), [3, 2, 1]);
    },
  );

  test('adding an existing favorite is a no-op', () async {
    await setUpContainer();
    await controller().add(repo(1));
    await controller().add(repo(1));
    expect(container.read(favoritesProvider), hasLength(1));
  });

  test('favorites survive a restart', () async {
    await setUpContainer();
    await controller().add(repo(1));
    await controller().add(repo(2));
    final persisted = container
        .read(sharedPreferencesProvider)
        .getString(SharedPreferencesFavoritesStorage.storageKey)!;

    // A fresh container reading the same stored value simulates relaunch.
    await setUpContainer({
      SharedPreferencesFavoritesStorage.storageKey: persisted,
    });

    expect(container.read(favoritesProvider).map((r) => r.id), [2, 1]);
    expect(container.read(isFavoriteProvider(1)), isTrue);
  });

  test('corrupt storage is ignored instead of crashing', () async {
    await setUpContainer({
      SharedPreferencesFavoritesStorage.storageKey: 'not json',
    });
    expect(container.read(favoritesProvider), isEmpty);
  });

  test('a single corrupt entry does not discard the others', () async {
    await setUpContainer({
      SharedPreferencesFavoritesStorage.storageKey: jsonEncode([
        {'id': 1, 'full_name': 'a/b', 'avatar_url': 'x'},
        {'id': 'oops'},
        {'id': 1, 'full_name': 'a/b', 'avatar_url': 'x'}, // duplicate
        {'id': 2, 'full_name': 'c/d', 'avatar_url': 'y'},
      ]),
    });
    expect(container.read(favoritesProvider).map((r) => r.id), [1, 2]);
  });

  test('state is rolled back when saving fails', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        favoritesStorageProvider.overrideWithValue(_FailingStorage()),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      controller().toggle(repo(1)),
      throwsA(isA<FavoritesPersistenceException>()),
    );
    expect(container.read(favoritesProvider), isEmpty);
  });
}

class _FailingStorage implements FavoritesStorage {
  @override
  List<RepositorySummary> load() => const [];

  @override
  Future<bool> save(List<RepositorySummary> favorites) async => false;
}
