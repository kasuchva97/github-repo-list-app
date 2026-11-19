/// Failures raised by the networking layer.
///
/// The hierarchy is `sealed` so the presentation layer can map every case to
/// a user-facing message with an exhaustive `switch`.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  /// Developer-facing description (also used for logging).
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The device is offline, DNS failed, the connection dropped or timed out.
final class NetworkException extends ApiException {
  const NetworkException(super.message, {this.isTimeout = false});

  final bool isTimeout;
}

/// GitHub's unauthenticated rate limit was hit (HTTP 403/429).
///
/// [resetAt] comes from the `x-ratelimit-reset` / `retry-after` headers when
/// GitHub provides them.
final class RateLimitException extends ApiException {
  const RateLimitException(super.message, {this.resetAt});

  final DateTime? resetAt;
}

/// The requested resource does not exist (HTTP 404), e.g. a deleted repo.
final class NotFoundException extends ApiException {
  const NotFoundException(super.message);
}

/// GitHub rejected the request (HTTP 422), e.g. paging past the 1,000 result
/// cap of the Search API or a malformed query.
final class ValidationException extends ApiException {
  const ValidationException(super.message);
}

/// Any other non-2xx response.
final class ServerException extends ApiException {
  const ServerException(super.message, {required this.statusCode});

  final int statusCode;
}

/// The response body could not be decoded into the expected shape.
final class ParseException extends ApiException {
  const ParseException(super.message);
}
