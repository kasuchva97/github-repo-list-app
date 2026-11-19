import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Thin wrapper around [http.Client] for the GitHub REST API.
///
/// Responsibilities:
/// * builds `https://api.github.com` URIs (query parameters are encoded),
/// * sends the headers GitHub recommends for REST API v2022-11-28,
/// * applies a request timeout,
/// * decodes JSON and maps every failure to a typed [ApiException].
///
/// No `Authorization` header is sent, as required by the assignment.
class GitHubHttpClient {
  GitHubHttpClient(
    this._client, {
    this.timeout = const Duration(seconds: 15),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const String host = 'api.github.com';
  static const String apiVersion = '2022-11-28';

  final http.Client _client;
  final Duration timeout;
  final DateTime Function() _clock;

  static const Map<String, String> _headers = {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': apiVersion,
  };

  /// Performs a GET request and returns the decoded JSON object.
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final uri = Uri.https(host, path, queryParameters);

    final http.Response response;
    try {
      response = await _client.get(uri, headers: _headers).timeout(timeout);
    } on TimeoutException {
      throw const NetworkException('The request timed out.', isTimeout: true);
    } on SocketException catch (e) {
      throw NetworkException('Network unreachable: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Connection failed: ${e.message}');
    } on HandshakeException catch (e) {
      throw NetworkException('Secure connection failed: ${e.message}');
    }

    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) {
      return _decode(response);
    }
    throw _mapError(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      throw const ParseException('Expected a JSON object.');
    } on FormatException catch (e) {
      throw ParseException('Malformed JSON: ${e.message}');
    }
  }

  ApiException _mapError(http.Response response) {
    final statusCode = response.statusCode;
    final message = _extractMessage(response) ?? 'HTTP $statusCode';
    final headers = response.headers;

    final isRateLimited =
        statusCode == 429 ||
        (statusCode == 403 &&
            (headers['x-ratelimit-remaining'] == '0' ||
                headers.containsKey('retry-after') ||
                message.toLowerCase().contains('rate limit')));

    if (isRateLimited) {
      return RateLimitException(message, resetAt: _parseResetAt(headers));
    }
    return switch (statusCode) {
      404 => NotFoundException(message),
      422 => ValidationException(message),
      _ => ServerException(message, statusCode: statusCode),
    };
  }

  String? _extractMessage(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic> && body['message'] is String) {
        return body['message'] as String;
      }
    } on FormatException {
      // Not JSON (e.g. an HTML error page from a proxy); fall through.
    }
    return null;
  }

  DateTime? _parseResetAt(Map<String, String> headers) {
    final retryAfter = int.tryParse(headers['retry-after'] ?? '');
    if (retryAfter != null) {
      return _clock().add(Duration(seconds: retryAfter));
    }
    final reset = int.tryParse(headers['x-ratelimit-reset'] ?? '');
    if (reset != null) {
      return DateTime.fromMillisecondsSinceEpoch(reset * 1000);
    }
    return null;
  }
}
