import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../application/search_controller.dart';
import '../../application/search_state.dart';
import '../../data/models/search_filters.dart';

/// Result count, sort menu and language chips shown above search results.
class SearchFilterBar extends ConsumerWidget {
  const SearchFilterBar({super.key, required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(repositorySearchProvider.notifier);
    final filters = state.filters;
    final theme = Theme.of(context);

    final showCount = !state.isLoading && state.error == null && !state.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  showCount
                      ? '${withSeparators(state.totalCount)} repositories'
                      : '',
                  key: const Key('result-count'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              PopupMenuButton<SearchSort>(
                key: const Key('sort-menu'),
                tooltip: 'Sort results',
                initialValue: filters.sort,
                onSelected: (sort) =>
                    controller.setFilters(filters.copyWith(sort: sort)),
                itemBuilder: (context) => [
                  for (final sort in SearchSort.values)
                    CheckedPopupMenuItem(
                      value: sort,
                      checked: sort == filters.sort,
                      child: Text(sort.label),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        filters.sort.label,
                        style: theme.textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            key: const Key('language-chips'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filterLanguages.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final language = filterLanguages[index];
              final selected = filters.language == language;
              return FilterChip(
                key: ValueKey('lang-$language'),
                label: Text(language),
                selected: selected,
                onSelected: (value) => controller.setFilters(
                  filters.copyWith(language: () => value ? language : null),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
