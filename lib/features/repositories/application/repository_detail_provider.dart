import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/models/repository_detail.dart';

/// Detail of one repository, keyed by `full_name`.
///
/// `autoDispose` frees the data when the detail screen is closed; reopening
/// fetches fresh numbers. Automatic retry is disabled (see `main.dart`) so a
/// 404 or rate-limit error is shown immediately with a manual Retry button
/// instead of silently spending the rate limit.
final repositoryDetailProvider = FutureProvider.autoDispose
    .family<RepositoryDetail, String>(
      (ref, fullName) =>
          ref.watch(gitHubRepositoryProvider).fetchRepository(fullName),
    );
