import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/search_history_controller.dart';

/// Ideas shown when the user has no recent searches yet.
const List<String> suggestedSearches = [
  'flutter',
  'riverpod',
  'dart',
  'machine learning',
  'kotlin multiplatform',
  'react native',
];

/// The Home screen of the Search tab (empty search box): a welcome message,
/// the user's recent searches and a few suggestions to tap.
class SearchHomeView extends ConsumerWidget {
  const SearchHomeView({super.key, required this.onPick});

  /// Called with the chosen keyword.
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final history = ref.watch(searchHistoryProvider);

    return ListView(
      key: const Key('search-home'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 8),
        Icon(Icons.travel_explore, size: 72, color: colors.primary),
        const SizedBox(height: 16),
        Text(
          'Search GitHub repositories',
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Type a keyword above, then tap the star to save repositories '
          'to your favorites.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent searches',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              TextButton(
                key: const Key('clear-history'),
                onPressed: () =>
                    ref.read(searchHistoryProvider.notifier).clear(),
                child: const Text('Clear'),
              ),
            ],
          ),
          for (final query in history)
            ListTile(
              key: ValueKey('recent-$query'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history),
              title: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                tooltip: 'Remove "$query"',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () =>
                    ref.read(searchHistoryProvider.notifier).remove(query),
              ),
              onTap: () => onPick(query),
            ),
        ],
        const SizedBox(height: 24),
        Text('Try searching for', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final suggestion in suggestedSearches)
              ActionChip(
                key: ValueKey('suggestion-$suggestion'),
                avatar: const Icon(Icons.trending_up, size: 18),
                label: Text(suggestion),
                onPressed: () => onPick(suggestion),
              ),
          ],
        ),
      ],
    );
  }
}
