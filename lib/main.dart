import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loaded before the first frame so favorites are available synchronously.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      // Riverpod 3 retries failed providers automatically. For a rate-limited
      // API that is counter-productive, so failures surface immediately and
      // the user retries explicitly.
      retry: (retryCount, error) => null,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const GitHubRepoListApp(),
    ),
  );
}
