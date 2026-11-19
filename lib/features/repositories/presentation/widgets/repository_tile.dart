import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/owner_avatar.dart';
import '../../../favorites/presentation/favorite_button.dart';
import '../../data/models/repository_summary.dart';
import '../repository_detail_screen.dart';

/// List row shared by the search and star lists: avatar, `full_name`,
/// optional description/metadata and a [FavoriteButton].
class RepositoryTile extends StatelessWidget {
  const RepositoryTile({super.key, required this.repository});

  final RepositorySummary repository;

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
      leading: OwnerAvatar(url: repository.ownerAvatarUrl),
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
      onTap: () => RepositoryDetailScreen.open(context, repository),
    );
  }
}

/// 1234 → "1.2k", 1500000 → "1.5M".
String compactNumber(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) return '${_trim(value / 1000)}k';
  return '${_trim(value / 1000000)}M';
}

String _trim(double v) {
  final s = v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}
