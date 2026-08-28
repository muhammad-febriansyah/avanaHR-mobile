import 'package:avanahr/app/data/providers/api_client.dart';
import 'package:avanahr/app/data/services/auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keeping a session alive without a connection.
///
/// A launch with no signal used to fail `/auth/me`, read that as "not
/// authenticated", and route to a login screen that needed the very network
/// that was missing — locking the employee out of the offline attendance queue
/// entirely. These cover the two rules that now decide it.
DioException _dio(DioExceptionType type, {int? status}) => DioException(
  requestOptions: RequestOptions(path: '/auth/me'),
  type: type,
  response: status == null
      ? null
      : Response(
          requestOptions: RequestOptions(path: '/auth/me'),
          statusCode: status,
        ),
);

void main() {
  group('ApiClient.isOffline', () {
    test('a connection that never opened is the network, not the server', () {
      expect(
        _dio(DioExceptionType.connectionError),
        predicate(ApiClient.isOffline),
      );
      expect(
        _dio(DioExceptionType.connectionTimeout),
        predicate(ApiClient.isOffline),
      );
      expect(
        _dio(DioExceptionType.sendTimeout),
        predicate(ApiClient.isOffline),
      );
      expect(
        _dio(DioExceptionType.receiveTimeout),
        predicate(ApiClient.isOffline),
      );
    });

    test('a 401 is the server refusing, and must still sign the user out', () {
      expect(
        ApiClient.isOffline(_dio(DioExceptionType.badResponse, status: 401)),
        isFalse,
      );
    });

    test('a 500 is the server too — the request did arrive', () {
      expect(
        ApiClient.isOffline(_dio(DioExceptionType.badResponse, status: 500)),
        isFalse,
      );
    });
  });

  group('offline session window', () {
    test('matches the server JWT_REFRESH_TTL of 90 days', () {
      // Past this the token can no longer be renewed even back online, so
      // holding the session open would only defer the login to a worse moment.
      // The server value lives in .env as JWT_REFRESH_TTL=129600 (minutes);
      // this test is what stops the two drifting apart silently.
      expect(AuthService.offlineSessionWindow, const Duration(days: 90));
      expect(AuthService.offlineSessionWindow.inMinutes, 129600);
    });
  });
}
