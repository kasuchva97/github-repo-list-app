import 'package:material_ui/material_ui.dart';

import '../../../../core/format.dart';
import '../../../../core/widgets/owner_avatar.dart';
import '../../../favorites/presentation/favorite_button.dart';
import '../../data/models/repository_summary.dart';
import '../repository_detail_screen.dart';

/// List row shared by the search and star lists: avatar, `full_name`,
/// optional description/metadata and a [FavoriteButton].
class RepositoryTile extends StatelessWidget {
  const RepositoryTile({super.key, required this.repository});

  final RepositorySummary repository;

  String get heroTag => 'search-avatar-${repository.id}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = repository.description;
    final meta = [
      if (repository.language != null) repository.language!,
      if (repository.stargazersCount != null)
        '★ ${compactNumber(repository.stargazersCount!)}',
    ].join('  ·  ');

    return ListTile(
      leading: OwnerAvatar(url: repository.ownerAvatarUrl, heroTag: heroTag),
      title: Text(
        repository.fullName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: description == null && meta.isEmpty
          ? null
          : Text(
              [
                if (description != null && description.isNotEmpty) description,
                if (meta.isNotEmpty) meta,
              ].join('\n'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: FavoriteButton(repository: repository),
      onTap: () =>
          RepositoryDetailScreen.open(context, repository, heroTag: heroTag),
    );
  }
}
