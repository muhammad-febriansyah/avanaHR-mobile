import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
        onError: (error, handler) {
          // What the toast no longer says out loud. The employee gets plain
          // words; the status and body land here, where they are of use.
          if (kDebugMode) {
            final response = error.response;
            debugPrint(
              '[api] ${error.requestOptions.method} '
              '${error.requestOptions.path} '
              '→ ${response?.statusCode ?? error.type.name}',
            );
            if (response?.data != null) {
              debugPrint('[api] body: ${response!.data}');
            }
          }

          handler.next(error);
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

    // The two-factor exchange runs before there is a session at all, so a 401
    // there is a spent challenge, not a lapsed token: nothing to renew and no
    // session to end. The screen that asked reads the status and sends the user
    // back to sign in itself.
    if (request.path.contains('/auth/two-factor')) {
      return (null, false);
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

    // An upload's body is a stream that can only be read once, and the first
    // attempt already drained it. Without a fresh copy the retry throws instead
    // of sending, so every photo posted on a lapsed token failed here.
    final body = request.data;
    if (body is FormData) {
      request.data = body.clone();
    }

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
  ///
  /// Laravel's 422 payload carries a generic top-level `message` ("The given
  /// data was invalid.") plus a per-field `errors` map with the actual
  /// validation text (e.g. "Ukuran foto maksimal 5 MB."). The field message is
  /// what the employee needs to see, so it takes priority when present.
  static String messageFrom(
    Response? response, [
    String fallback = 'Terjadi kesalahan.',
  ]) {
    final data = response?.data;
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty && first.first is String) {
          return first.first as String;
        }
        if (first is String && first.isNotEmpty) {
          return first;
        }
      }

      if (data['message'] is String && (data['message'] as String).isNotEmpty) {
        return data['message'] as String;
      }
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
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;

        // The server answered, so blaming the connection would send people off
        // to check a network that is working fine. Say whose side broke and
        // nothing more: a status code means nothing to the employee holding the
        // phone, and it is already in the debug log for whoever fixes it.
        if (status != null && status >= 500) {
          return messageFrom(
            e.response,
            'Sistem sedang bermasalah. Ini bukan dari jaringan kamu — coba '
            'lagi beberapa saat.',
          );
        }

        return messageFrom(e.response, 'Permintaan tidak bisa diproses.');
      default:
        return messageFrom(
          e.response,
          'Gagal menghubungi server. Coba lagi sebentar.',
        );
    }
  }
}
