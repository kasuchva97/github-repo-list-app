import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:github_repo_list/core/network/api_exception.dart';
import 'package:github_repo_list/core/network/github_http_client.dart';
import 'package:github_repo_list/core/widgets/error_messages.dart';
import 'package:github_repo_list/features/repositories/data/github_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late http.Request lastRequest;

  GitHubRepository repositoryFor(
    http.Response Function(http.Request request) handler,
  ) {
    final client = MockClient((request) async {
      lastRequest = request;
      return handler(request);
    });
    return GitHubRepositoryImpl(
      GitHubHttpClient(client, clock: () => DateTime.utc(2026)),
    );
  }

  http.Response json(Object body, {int status = 200, Map<String, String>? h}) =>
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8', ...?h},
      );

  group('searchRepositories', () {
    test('builds the request and parses items', () async {
      final repository = repositoryFor(
        (_) => json({
          'total_count': 2,
          'incomplete_results': false,
          'items': [
            {
              'id': 31792824,
              'full_name': 'flutter/flutter',
              'description': 'Flutter makes it easy…',
              'language': 'Dart',
              'stargazers_count': 170000,
              'owner': {
                'login': 'flutter',
                'avatar_url':
                    'https://avatars.githubusercontent.com/u/14101776?v=4',
              },
            },
            {
              'id': 2,
              'full_name': 'a/b',
              'owner': {'avatar_url': 'https://example.com/a.png'},
            },
          ],
        }),
      );

      final page = await repository.searchRepositories('flutter ui', page: 2);

      expect(lastRequest.method, 'GET');
      expect(lastRequest.url.host, 'api.github.com');
      expect(lastRequest.url.path, '/search/repositories');
      expect(lastRequest.url.queryParameters, {
        'q': 'flutter ui',
        'page': '2',
        'per_page': '30',
      });
      expect(lastRequest.headers['Accept'], 'application/vnd.github+json');
      expect(lastRequest.headers['X-GitHub-Api-Version'], '2022-11-28');
      expect(lastRequest.headers.containsKey('Authorization'), isFalse);

      expect(page.totalCount, 2);
      expect(page.items.first.id, 31792824);
      expect(page.items.first.fullName, 'flutter/flutter');
      expect(
        page.items.first.ownerAvatarUrl,
        'https://avatars.githubusercontent.com/u/14101776?v=4',
      );
      expect(page.items.first.language, 'Dart');
      expect(page.items.last.description, isNull);
    });

    test('maps 403 with exhausted quota to RateLimitException', () async {
      final repository = repositoryFor(
        (_) => json(
          {'message': 'API rate limit exceeded for 1.2.3.4.'},
          status: 403,
          h: {'x-ratelimit-remaining': '0', 'x-ratelimit-reset': '1767225660'},
        ),
      );

      final error = await repository
          .searchRepositories('x', page: 1)
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(error, isA<RateLimitException>());
      final rateLimit = error! as RateLimitException;
      expect(
        rateLimit.resetAt,
        DateTime.fromMillisecondsSinceEpoch(1767225660 * 1000),
      );
      expect(
        userMessageFor(error, now: DateTime.utc(2026)),
        contains('Try again in 1 minute'),
      );
    });

    test('maps 422 to ValidationException', () {
      final repository = repositoryFor(
        (_) => json({'message': 'Validation Failed'}, status: 422),
      );
      expect(
        repository.searchRepositories('x', page: 50),
        throwsA(isA<ValidationException>()),
      );
    });

    test('maps 503 with an HTML body to ServerException', () {
      final repository = repositoryFor(
        (_) => http.Response('<html>oops</html>', 503),
      );
      expect(
        repository.searchRepositories('x', page: 1),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 503),
        ),
      );
    });

    test('maps socket errors to NetworkException', () {
      final repository = repositoryFor(
        (_) => throw const SocketException('Failed host lookup'),
      );
      expect(
        repository.searchRepositories('x', page: 1),
        throwsA(isA<NetworkException>()),
      );
    });

    test('maps malformed JSON to ParseException', () {
      final repository = repositoryFor((_) => http.Response('{not json', 200));
      expect(
        repository.searchRepositories('x', page: 1),
        throwsA(isA<ParseException>()),
      );
    });

    test('maps an unexpected payload shape to ParseException', () {
      final repository = repositoryFor(
        (_) => json({
          'total_count': 1,
          'items': [
            {'id': 'not-an-int', 'full_name': 'a/b'},
          ],
        }),
      );
      expect(
        repository.searchRepositories('x', page: 1),
        throwsA(isA<ParseException>()),
      );
    });
  });

  group('fetchRepository', () {
    test(
      'requests /repos/{owner}/{repo} and parses subscribers_count',
      () async {
        final repository = repositoryFor(
          (_) => json({
            'id': 31792824,
            'full_name': 'flutter/flutter',
            'subscribers_count': 3456,
            'watchers_count': 170000,
            'stargazers_count': 170000,
            'forks_count': 28000,
            'open_issues_count': 12000,
            'language': 'Dart',
            'owner': {
              'avatar_url':
                  'https://avatars.githubusercontent.com/u/14101776?v=4',
            },
          }),
        );

        final detail = await repository.fetchRepository('flutter/flutter');

        expect(lastRequest.url.path, '/repos/flutter/flutter');
        expect(detail.subscribersCount, 3456);
        expect(detail.stargazersCount, 170000);
        expect(detail.fullName, 'flutter/flutter');
      },
    );

    test('maps 404 to NotFoundException', () {
      final repository = repositoryFor(
        (_) => json({'message': 'Not Found'}, status: 404),
      );
      expect(
        repository.fetchRepository('gone/away'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('rejects malformed names without a network call', () async {
      var called = false;
      final repository = repositoryFor((_) {
        called = true;
        return json({});
      });
      await expectLater(
        repository.fetchRepository('../etc/passwd'),
        throwsA(isA<ValidationException>()),
      );
      expect(called, isFalse);
    });
  });
}
