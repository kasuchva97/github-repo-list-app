import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../favorites/application/favorites_controller.dart';
import '../favorites/presentation/favorites_screen.dart';
import '../repositories/presentation/search_screen.dart';

/// Root screen with a [BottomNavigationBar] for the Search and Star tabs.
///
/// Tabs live in an [IndexedStack] so each keeps its state (query, results,
/// scroll position) when the user switches back and forth.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _tabs = [SearchScreen(), FavoritesScreen()];

  @override
  Widget build(BuildContext context) {
    final favoriteCount = ref.watch(favoritesProvider.select((f) => f.length));

    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (index) {
          // Dismiss the keyboard when leaving the search tab.
          FocusScope.of(context).unfocus();
          setState(() => _index = index);
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
