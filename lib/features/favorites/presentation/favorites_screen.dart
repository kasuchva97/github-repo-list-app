import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/owner_avatar.dart';
import '../../../core/widgets/status_view.dart';
import '../../repositories/data/models/repository_summary.dart';
import '../../repositories/presentation/repository_detail_screen.dart';
import '../application/favorites_controller.dart';

/// Star tab: the favorited repositories, newest first.
///
/// Tapping the star (or swiping a row away) removes the repository, with an
/// Undo snackbar. A filter field appears once the list gets long.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  /// The filter field is only useful for longer lists.
  static const int filterThreshold = 5;

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final showFilter = favorites.length >= FavoritesScreen.filterThreshold;
    final needle = showFilter ? _filter.trim().toLowerCase() : '';
    final visible = needle.isEmpty
        ? favorites
        : favorites
              .where((r) => r.fullName.toLowerCase().contains(needle))
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          favorites.isEmpty ? 'Favorites' : 'Favorites (${favorites.length})',
        ),
      ),
      body: favorites.isEmpty
          ? const StatusView(
              key: Key('favorites-empty'),
              icon: Icons.star_border,
              title: 'No favorites yet',
              message:
                  'Tap the star next to a repository in Search '
                  'to keep it here.',
            )
          : Column(
              children: [
                if (showFilter)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      key: const Key('favorites-filter'),
                      onChanged: (value) => setState(() => _filter = value),
                      autocorrect: false,
                      decoration: InputDecoration(
                        hintText: 'Filter favorites',
                        prefixIcon: const Icon(Icons.filter_list),
                        filled: true,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: visible.isEmpty
                      ? StatusView(
                          key: const Key('favorites-no-match'),
                          icon: Icons.search_off,
                          title: 'No matching favorites',
                          message: 'None of your favorites match "$_filter".',
                        )
                      : ListView.separated(
                          key: const Key('favorites-list'),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, indent: 72),
                          itemBuilder: (context, index) =>
                              _FavoriteTile(repo: visible[index]),
                        ),
                ),
              ],
            ),
    );
  }
}

class _FavoriteTile extends ConsumerWidget {
  const _FavoriteTile({required this.repo});

  final RepositorySummary repo;

  String get _heroTag => 'favorite-avatar-${repo.id}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('dismiss-${repo.id}'),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: colors.errorContainer,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Icon(Icons.star_border, color: colors.onErrorContainer),
          ),
        ),
      ),
      onDismissed: (_) => _remove(context, ref),
      child: ListTile(
        leading: OwnerAvatar(url: repo.ownerAvatarUrl, heroTag: _heroTag),
        title: Text(
          repo.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          key: ValueKey('favorite-${repo.id}'),
          tooltip: 'Remove from favorites',
          isSelected: true,
          icon: const Icon(Icons.star_border),
          selectedIcon: Icon(Icons.star, color: colors.tertiary),
          onPressed: () => _remove(context, ref),
        ),
        onTap: () =>
            RepositoryDetailScreen.open(context, repo, heroTag: _heroTag),
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(favoritesProvider.notifier);
    try {
      final index = await controller.remove(repo.id);
      if (index < 0) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Removed ${repo.fullName}'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => controller.add(repo, index: index),
            ),
          ),
        );
    } on FavoritesPersistenceException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update favorites.')),
      );
    }
  }
}
