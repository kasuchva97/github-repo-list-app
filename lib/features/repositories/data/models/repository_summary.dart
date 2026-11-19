import 'package:flutter/foundation.dart';

/// A repository as it appears in lists (search results and favorites).
///
/// Only [id], [fullName] and [ownerAvatarUrl] are required: they are the
/// fields persisted for favorites. The remaining fields are optional extras
/// shown when available from the Search API.
@immutable
class RepositorySummary {
  const RepositorySummary({
    required this.id,
    required this.fullName,
    required this.ownerAvatarUrl,
    this.description,
    this.language,
    this.stargazersCount,
  });

  /// Parses an item of the Search API's `items` array.
  factory RepositorySummary.fromSearchJson(Map<String, dynamic> json) {
    final owner = json['owner'];
    return RepositorySummary(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      ownerAvatarUrl: owner is Map<String, dynamic>
          ? owner['avatar_url'] as String? ?? ''
          : '',
      description: json['description'] as String?,
      language: json['language'] as String?,
      stargazersCount: json['stargazers_count'] as int?,
    );
  }

  /// Parses the compact JSON stored in shared_preferences.
  factory RepositorySummary.fromFavoriteJson(Map<String, dynamic> json) {
    return RepositorySummary(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      ownerAvatarUrl: json['avatar_url'] as String? ?? '',
    );
  }

  final int id;

  /// `owner/name`, e.g. `flutter/flutter`.
  final String fullName;
  final String ownerAvatarUrl;
  final String? description;
  final String? language;
  final int? stargazersCount;

  String get ownerLogin => fullName.split('/').first;
  String get name => fullName.split('/').last;

  /// The subset persisted for favorites: `id`, `full_name`,
  /// `owner.avatar_url` (as required by the assignment).
  Map<String, dynamic> toFavoriteJson() => {
    'id': id,
    'full_name': fullName,
    'avatar_url': ownerAvatarUrl,
  };

  /// Repositories are identified by their immutable GitHub [id]; the name can
  /// change (renames, transfers) without it becoming a different repository.
  @override
  bool operator ==(Object other) =>
      other is RepositorySummary && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'RepositorySummary($id, $fullName)';
}
