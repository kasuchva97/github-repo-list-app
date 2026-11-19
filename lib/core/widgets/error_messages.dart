import '../network/api_exception.dart';

/// Maps any error to a short, user-facing message.
///
/// Kept in one place so every screen speaks the same language.
String userMessageFor(Object error, {DateTime? now}) {
  if (error is! ApiException) {
    return 'Something went wrong. Please try again.';
  }
  return switch (error) {
    NetworkException(isTimeout: true) =>
      'The request timed out. Check your connection and try again.',
    NetworkException() =>
      'You appear to be offline. Check your connection and try again.',
    RateLimitException(:final resetAt) => _rateLimitMessage(resetAt, now),
    NotFoundException() =>
      'This repository could not be found. '
          'It may have been renamed, deleted or made private.',
    ValidationException() =>
      'GitHub could not process this search. Try a different keyword.',
    ServerException(:final statusCode) =>
      'GitHub returned an error ($statusCode). Please try again later.',
    ParseException() =>
      'GitHub sent an unexpected response. Please try again later.',
  };
}

String _rateLimitMessage(DateTime? resetAt, DateTime? now) {
  const base = 'GitHub\'s request limit was reached.';
  if (resetAt == null) return '$base Please wait a minute and try again.';
  final remaining = resetAt.difference(now ?? DateTime.now());
  if (remaining.inSeconds <= 0) return '$base You can try again now.';
  if (remaining.inSeconds < 60) {
    return '$base Try again in ${remaining.inSeconds} seconds.';
  }
  final minutes = (remaining.inSeconds / 60).ceil();
  return '$base Try again in $minutes minute${minutes == 1 ? '' : 's'}.';
}
