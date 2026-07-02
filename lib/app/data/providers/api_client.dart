import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;

import '../../core/config/env.dart';
import '../../routes/app_pages.dart';
import '../services/storage_service.dart';

/// Central Dio client for the AvanaHR API. Attaches the JWT on every request
/// and bounces the user back to login on a 401.
class ApiClient extends GetxService {
  late final Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = Get.find<StorageService>().token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (response.statusCode == 401) {
            Get.find<StorageService>().clearToken();
            if (Get.currentRoute != Routes.LOGIN) {
              Get.offAllNamed(Routes.LOGIN);
            }
          }
          handler.next(response);
        },
      ),
    );
  }

  /// Extract a friendly message from an error-shaped response body.
  static String messageFrom(Response? response, [String fallback = 'Terjadi kesalahan.']) {
    final data = response?.data;
    if (data is Map && data['message'] is String && (data['message'] as String).isNotEmpty) {
      return data['message'] as String;
    }
    return fallback;
  }
}
