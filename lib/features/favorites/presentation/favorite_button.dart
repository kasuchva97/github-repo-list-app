import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../repositories/data/models/repository_summary.dart';
import '../application/favorites_controller.dart';

/// Star toggle used on every screen.
///
/// It reads its on/off state from [isFavoriteProvider], so all instances for
/// the same repository stay in sync automatically.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.repository});

  final RepositorySummary repository;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(repository.id));
    final colors = Theme.of(context).colorScheme;

    return IconButton(
      key: ValueKey('favorite-${repository.id}'),
      tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      isSelected: isFavorite,
      icon: const Icon(Icons.star_border),
      selectedIcon: Icon(Icons.star, color: colors.tertiary),
      onPressed: () => toggleFavorite(context, ref, repository),
    );
  }
}

/// Toggles [repository] and reports a storage failure, if any.
Future<void> toggleFavorite(
  BuildContext context,
  WidgetRef ref,
  RepositorySummary repository,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await ref.read(favoritesProvider.notifier).toggle(repository);
  } on FavoritesPersistenceException {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Could not update favorites.')),
      );
  }
}
