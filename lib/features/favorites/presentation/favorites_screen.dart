import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/owner_avatar.dart';
import '../../../core/widgets/status_view.dart';
import '../../repositories/data/models/repository_summary.dart';
import '../../repositories/presentation/repository_detail_screen.dart';
import '../application/favorites_controller.dart';

/// Star tab: the favorited repositories, newest first.
///
/// Tapping the star removes the repository (with an Undo snackbar).
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: favorites.isEmpty
          ? const StatusView(
              key: Key('favorites-empty'),
              icon: Icons.star_border,
              title: 'No favorites yet',
              message:
                  'Tap the star next to a repository in Search '
                  'to keep it here.',
            )
          : ListView.separated(
              key: const Key('favorites-list'),
              itemCount: favorites.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final repo = favorites[index];
                return ListTile(
                  key: ValueKey(repo.id),
                  leading: OwnerAvatar(url: repo.ownerAvatarUrl),
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
                    selectedIcon: Icon(
                      Icons.star,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    onPressed: () => _remove(context, ref, repo),
                  ),
                  onTap: () => RepositoryDetailScreen.open(context, repo),
                );
              },
            ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    RepositorySummary repo,
  ) async {
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
