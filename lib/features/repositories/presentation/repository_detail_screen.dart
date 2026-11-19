import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/error_messages.dart';
import '../../../core/widgets/owner_avatar.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../application/repository_detail_provider.dart';
import '../application/search_controller.dart';
import '../data/models/repository_detail.dart';
import '../data/models/repository_summary.dart';

/// Repository Detail screen: `full_name`, `owner.avatar_url` and
/// `subscribers_count`, plus a star toggle.
///
/// It is opened with the [RepositorySummary] the user tapped, so the header
/// (name, avatar, star) renders instantly while the detail request is still
/// in flight; only the statistics wait for the network.
class RepositoryDetailScreen extends ConsumerWidget {
  const RepositoryDetailScreen({
    super.key,
    required this.repository,
    this.heroTag,
  });

  final RepositorySummary repository;

  /// Matches the tag of the avatar in the list that opened this screen.
  final Object? heroTag;

  static Future<void> open(
    BuildContext context,
    RepositorySummary repository, {
    Object? heroTag,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RepositoryDetailScreen(repository: repository, heroTag: heroTag),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(repositoryDetailProvider(repository.fullName));

    return Scaffold(
      appBar: AppBar(
        title: Text(repository.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            key: const Key('copy-link'),
            tooltip: 'Copy GitHub link',
            icon: const Icon(Icons.link),
            onPressed: () => _copyLink(context),
          ),
          FavoriteButton(repository: repository),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.refresh(repositoryDetailProvider(repository.fullName).future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            _Header(
              repository: repository,
              detail: detail.value,
              heroTag: heroTag,
            ),
            const SizedBox(height: 32),
            switch (detail) {
              AsyncData(:final value) => _Statistics(detail: value),
              AsyncError(:final error) => _ErrorPanel(
                message: userMessageFor(error),
                onRetry: () => ref.invalidate(
                  repositoryDetailProvider(repository.fullName),
                ),
              ),
              _ => const Padding(
                key: Key('detail-loading'),
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            },
          ],
        ),
      ),
    );
  }
}

extension on RepositoryDetailScreen {
  Future<void> _copyLink(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(text: 'https://github.com/${repository.fullName}'),
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Link copied')));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.repository, this.detail, this.heroTag});

  final RepositorySummary repository;
  final RepositoryDetail? detail;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = detail?.description ?? repository.description;
    return Column(
      children: [
        OwnerAvatar(url: repository.ownerAvatarUrl, size: 96, heroTag: heroTag),
        const SizedBox(height: 16),
        SelectableText(
          repository.fullName,
          key: const Key('detail-full-name'),
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _Statistics extends ConsumerWidget {
  const _Statistics({required this.detail});

  final RepositoryDetail detail;

  /// Jumps to the Search tab and searches for [topic].
  void _searchTopic(BuildContext context, WidgetRef ref, String topic) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    ref.read(selectedTabProvider.notifier).select(0);
    unawaited(ref.read(repositorySearchProvider.notifier).search(topic));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The required field, given prominence.
        _StatCard(
          key: const Key('detail-subscribers'),
          icon: Icons.visibility_outlined,
          label: 'Watchers (subscribers)',
          value: detail.subscribersCount,
          emphasized: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.star_outline,
                label: 'Stars',
                value: detail.stargazersCount,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.call_split,
                label: 'Forks',
                value: detail.forksCount,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.error_outline,
                label: 'Issues',
                value: detail.openIssuesCount,
              ),
            ),
          ],
        ),
        if (detail.language != null ||
            detail.licenseName != null ||
            detail.pushedAt != null) ...[
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (detail.language != null)
                Chip(
                  avatar: const Icon(Icons.code, size: 18),
                  label: Text(detail.language!),
                ),
              if (detail.licenseName != null)
                Chip(
                  avatar: const Icon(Icons.balance, size: 18),
                  label: Text(detail.licenseName!),
                ),
              if (detail.pushedAt != null)
                Chip(
                  key: const Key('detail-updated'),
                  avatar: const Icon(Icons.update, size: 18),
                  label: Text('Updated ${relativeTime(detail.pushedAt!)}'),
                ),
            ],
          ),
        ],
        if (detail.topics.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            key: const Key('detail-topics'),
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final topic in detail.topics.take(12))
                ActionChip(
                  label: Text(topic),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _searchTopic(context, ref, topic),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final int value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Card.filled(
        color: emphasized ? colors.primaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(
                icon,
                color: emphasized ? colors.onPrimaryContainer : colors.primary,
              ),
              const SizedBox(height: 8),
              Text(
                emphasized ? withSeparators(value) : compactNumber(value),
                style:
                    (emphasized
                            ? theme.textTheme.headlineMedium
                            : theme.textTheme.titleLarge)
                        ?.copyWith(
                          color: emphasized ? colors.onPrimaryContainer : null,
                        ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: emphasized
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('detail-error'),
      children: [
        Icon(
          Icons.cloud_off,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
