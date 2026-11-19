import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../features/favorites/data/favorites_storage.dart';
import '../features/repositories/data/github_repository.dart';
import 'network/github_http_client.dart';

/// App-wide dependency graph.
///
/// Every external dependency is a provider so tests can override it with a
/// fake (see `test/helpers`).

/// Initialised in `main()` before `runApp` and injected with
/// `sharedPreferencesProvider.overrideWithValue(prefs)`. Loading it up front
/// means favorites are available synchronously on the very first frame, so
/// star icons never flicker from "off" to "on" at launch.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  ),
);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final gitHubHttpClientProvider = Provider<GitHubHttpClient>(
  (ref) => GitHubHttpClient(ref.watch(httpClientProvider)),
);

final gitHubRepositoryProvider = Provider<GitHubRepository>(
  (ref) => GitHubRepositoryImpl(ref.watch(gitHubHttpClientProvider)),
);

final favoritesStorageProvider = Provider<FavoritesStorage>(
  (ref) =>
      SharedPreferencesFavoritesStorage(ref.watch(sharedPreferencesProvider)),
);

/// Index of the selected bottom navigation tab (0 = Search, 1 = Star).
///
/// A provider (rather than widget state) so other screens can switch tabs,
/// e.g. tapping a topic on the detail screen jumps to Search.
final selectedTabProvider = NotifierProvider<SelectedTab, int>(SelectedTab.new);

class SelectedTab extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}
