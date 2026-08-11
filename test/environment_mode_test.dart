import 'package:avanahr/app/core/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses a define when selected and development otherwise', () {
    const expectedEnvironment = String.fromEnvironment('APP_ENV');
    const expectedApiBaseUrl = String.fromEnvironment('API_BASE_URL');

    if (expectedEnvironment.isNotEmpty) {
      expect(Env.environment, expectedEnvironment);
      expect(Env.apiBaseUrl, expectedApiBaseUrl);
    } else {
      expect(Env.environment, 'development');
    }
  });

  test('selects dev for ordinary runs and production for release', () {
    expect(
      Env.resolveApiBaseUrl(releaseMode: false),
      'https://dev.avanahr.id/api/v1',
    );
    expect(
      Env.resolveApiBaseUrl(releaseMode: true),
      'https://avanahr.id/api/v1',
    );
    expect(
      Env.resolveApiBaseUrl(
        releaseMode: true,
        definedApiBaseUrl: 'https://staging.example/api/v1',
      ),
      'https://staging.example/api/v1',
    );
  });
}
