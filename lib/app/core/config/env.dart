import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to runtime configuration loaded from the `.env` asset.
class Env {
  static const environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: kReleaseMode ? 'production' : 'development',
  );

  static const _definedApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Debug/profile runs use the development API while release builds always
  /// use production. A compile-time define remains available as an explicit
  /// override for CI or one-off environments.
  static String get apiBaseUrl {
    return resolveApiBaseUrl(
      releaseMode: kReleaseMode,
      definedApiBaseUrl: _definedApiBaseUrl,
      developmentApiBaseUrl: dotenv.maybeGet('API_BASE_URL'),
    );
  }

  static String resolveApiBaseUrl({
    required bool releaseMode,
    String definedApiBaseUrl = '',
    String? developmentApiBaseUrl,
  }) {
    if (definedApiBaseUrl.isNotEmpty) {
      return definedApiBaseUrl;
    }
    if (releaseMode) {
      return 'https://avanahr.id/api/v1';
    }

    return developmentApiBaseUrl ?? 'https://dev.avanahr.id/api/v1';
  }

  /// Scheme + host + port of the API (drops the `/api/v1` path), e.g.
  /// `http://127.0.0.1:8000`. Media lives on the same origin as the API.
  static String get apiOrigin {
    final u = Uri.parse(apiBaseUrl);

    return '${u.scheme}://${u.host}${u.hasPort ? ':${u.port}' : ''}';
  }

  /// Re-root a media URL at [apiOrigin] so images/files load on any client
  /// regardless of the host the backend baked in (localhost / LAN / prod).
  /// Handles absolute URLs and bare paths; preserves null/empty as null.
  static String? resolveMedia(String? url) {
    if (url == null || url.isEmpty) {
      return null;
    }

    final u = Uri.tryParse(url);
    if (u == null || u.path.isEmpty) {
      return url;
    }

    final origin = Uri.parse(apiOrigin);

    return u
        .replace(
          scheme: origin.scheme,
          host: origin.host,
          port: origin.hasPort ? origin.port : 0,
        )
        .toString();
  }
}
