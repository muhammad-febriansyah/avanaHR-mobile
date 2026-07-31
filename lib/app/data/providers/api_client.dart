import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;

import '../../core/config/env.dart';
import '../../routes/app_pages.dart';
import '../services/storage_service.dart';

/// How an attempt to renew the token ended. `unreachable` is kept apart from
/// `refused` so a flat network never signs anybody out.
enum _Renewal { renewed, refused, unreachable }

/// Central Dio client for the AvanaHR API. Attaches the JWT on every request,
/// renews it when it lapses, and only bounces the user back to login once
/// renewal itself is refused.
///
/// Tokens are short-lived by design — an hour by default — so a 401 mid-session
/// is the normal course of events, not an error. Treating it as one used to
/// throw people out of a live recording an hour in.
class ApiClient extends GetxService {
  late final Dio dio;

  /// Bare client for the renewal call: it must not pass back through the
  /// interceptor below, or a refused renewal would try to renew itself.
  late final Dio _plain;

  /// The renewal in flight, if any.
  ///
  /// The server retires a token the moment it issues a replacement, so several
  /// requests failing at once must share one renewal rather than each spending
  /// the token the others still need.
  Future<_Renewal>? _renewal;

  /// Requests already retried once, so a token that is refused twice ends the
  /// session instead of looping.
  static const _retriedKey = 'avana.retried';

  ApiClient() {
    final options = BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
      validateStatus: (status) => status != null && status < 500,
    );

    dio = Dio(options);
    _plain = Dio(options);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = Get.find<StorageService>().token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          if (response.statusCode != 401) {
            handler.next(response);
            return;
          }

          final (retried, sessionOver) = await _recover(response.requestOptions);

          if (retried != null) {
            handler.resolve(retried);
            return;
          }

          if (sessionOver) {
            _endSession();
          }

          handler.next(response);
        },
      ),
    );
  }

  /// Try to put a working token behind a request that came back 401 and run it
  /// again.
  ///
  /// Returns the second attempt's response when there was one, and whether the
  /// session is over — those are separate answers, because a renewal that never
  /// reached the server says nothing about whether the session is still good.
  Future<(Response?, bool)> _recover(RequestOptions request) async {
    // Signing in and renewing are the two calls where a 401 means what it says.
    if (request.path.contains('/auth/login') ||
        request.path.contains('/auth/refresh')) {
      return (null, true);
    }

    if (request.extra[_retriedKey] == true) {
      return (null, true);
    }

    final storage = Get.find<StorageService>();
    final sent = request.headers['Authorization'];
    final current = storage.token;

    // Somebody else's renewal already landed while this request was in the air;
    // its token is simply out of date, so there is nothing to renew.
    final stale = current != null && sent != 'Bearer $current';

    if (!stale) {
      final outcome = await _renew();

      if (outcome != _Renewal.renewed) {
        return (null, outcome == _Renewal.refused);
      }
    }

    request.extra[_retriedKey] = true;
    request.headers.remove('Authorization');

    try {
      return (await dio.fetch(request), false);
    } on DioException {
      return (null, false);
    }
  }

  /// Exchange the stored token for a new one, at most one exchange at a time.
  Future<_Renewal> _renew() {
    return _renewal ??= _performRenewal().whenComplete(() => _renewal = null);
  }

  Future<_Renewal> _performRenewal() async {
    final storage = Get.find<StorageService>();
    final token = storage.token;

    if (token == null || token.isEmpty) {
      return _Renewal.refused;
    }

    try {
      final response = await _plain.post<Map<String, dynamic>>(
        '/auth/refresh',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final fresh = response.data?['access_token'];

      if (response.statusCode != 200 || fresh is! String || fresh.isEmpty) {
        return _Renewal.refused;
      }

      await storage.saveToken(fresh);

      return _Renewal.renewed;
    } on DioException {
      // A dead connection is not an expired session — leave the token where it
      // is so the next try on a working network can still use it.
      return _Renewal.unreachable;
    }
  }

  void _endSession() {
    Get.find<StorageService>().clearToken();

    if (Get.currentRoute != Routes.LOGIN) {
      Get.offAllNamed(Routes.LOGIN);
    }
  }

  /// Extract a friendly message from an error-shaped response body.
  static String messageFrom(
    Response? response, [
    String fallback = 'Terjadi kesalahan.',
  ]) {
    final data = response?.data;
    if (data is Map &&
        data['message'] is String &&
        (data['message'] as String).isNotEmpty) {
      return data['message'] as String;
    }
    return fallback;
  }

  /// Friendly message for a DioException, distinguishing a network/connectivity
  /// problem (no or bad internet) from a server-side error.
  static String errorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Koneksi internet buruk atau tidak ada. Periksa jaringan lalu coba lagi.';
      default:
        return messageFrom(e.response, 'Gagal terhubung ke server.');
    }
  }
}
