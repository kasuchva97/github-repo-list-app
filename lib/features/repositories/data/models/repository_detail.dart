import 'package:flutter/foundation.dart';

import 'repository_summary.dart';

/// Response of the Repository Detail API (`GET /repos/{owner}/{repo}`).
@immutable
class RepositoryDetail {
  const RepositoryDetail({
    required this.id,
    required this.fullName,
    required this.ownerAvatarUrl,
    required this.subscribersCount,
    this.description,
    this.language,
    this.htmlUrl,
    this.stargazersCount = 0,
    this.forksCount = 0,
    this.openIssuesCount = 0,
  });

  factory RepositoryDetail.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'];
    return RepositoryDetail(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      ownerAvatarUrl: owner is Map<String, dynamic>
          ? owner['avatar_url'] as String? ?? ''
          : '',
      // `subscribers_count` is the number of watchers. (`watchers_count` in
      // the API is, confusingly, the star count.)
      subscribersCount: json['subscribers_count'] as int? ?? 0,
      description: json['description'] as String?,
      language: json['language'] as String?,
      htmlUrl: json['html_url'] as String?,
      stargazersCount: json['stargazers_count'] as int? ?? 0,
      forksCount: json['forks_count'] as int? ?? 0,
      openIssuesCount: json['open_issues_count'] as int? ?? 0,
    );
  }

  final int id;
  final String fullName;
  final String ownerAvatarUrl;
  final int subscribersCount;
  final String? description;
  final String? language;
  final String? htmlUrl;
  final int stargazersCount;
  final int forksCount;
  final int openIssuesCount;

  RepositorySummary toSummary() => RepositorySummary(
    id: id,
    fullName: fullName,
    ownerAvatarUrl: ownerAvatarUrl,
    description: description,
    language: language,
    stargazersCount: stargazersCount,
  );
}
