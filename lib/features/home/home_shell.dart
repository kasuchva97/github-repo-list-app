import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../favorites/application/favorites_controller.dart';
import '../favorites/presentation/favorites_screen.dart';
import '../repositories/presentation/search_screen.dart';

/// Root screen with a [BottomNavigationBar] for the Search and Star tabs.
///
/// Tabs live in an [IndexedStack] so each keeps its state (query, results,
/// scroll position) when the user switches back and forth.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _tabs = [SearchScreen(), FavoritesScreen()];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(selectedTabProvider);
    final favoriteCount = ref.watch(favoritesProvider.select((f) => f.length));

    return Scaffold(
      body: IndexedStack(index: index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) {
          // Dismiss the keyboard when leaving the search tab.
          FocusScope.of(context).unfocus();
          ref.read(selectedTabProvider.notifier).select(i);
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: favoriteCount > 0,
              label: Text('$favoriteCount'),
              child: const Icon(Icons.star_border),
            ),
            activeIcon: Badge(
              isLabelVisible: favoriteCount > 0,
              label: Text('$favoriteCount'),
              child: const Icon(Icons.star),
            ),
            label: 'Star',
          ),
        ],
      ),
    );
  }
}
