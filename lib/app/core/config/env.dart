import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to runtime configuration loaded from the `.env` asset.
class Env {
  static String get apiBaseUrl =>
      dotenv.maybeGet('API_BASE_URL') ?? 'http://127.0.0.1:8000/api/v1';
}
