import 'package:avanahr/app/core/config/env.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://127.0.0.1:8000/api/v1');
  });

  test('apiOrigin drops the /api/v1 path', () {
    expect(Env.apiOrigin, 'http://127.0.0.1:8000');
  });

  group('resolveMedia', () {
    test('re-roots an absolute localhost URL to the API origin', () {
      expect(
        Env.resolveMedia('http://localhost:8000/storage/onboarding/x.svg'),
        'http://127.0.0.1:8000/storage/onboarding/x.svg',
      );
    });

    test('re-roots a bare path to the API origin', () {
      expect(
        Env.resolveMedia('/storage/photo.png'),
        'http://127.0.0.1:8000/storage/photo.png',
      );
    });

    test('preserves the query string', () {
      expect(
        Env.resolveMedia('http://10.0.2.2:8000/storage/a.jpg?v=2'),
        'http://127.0.0.1:8000/storage/a.jpg?v=2',
      );
    });

    test('returns null for null or empty', () {
      expect(Env.resolveMedia(null), isNull);
      expect(Env.resolveMedia(''), isNull);
    });
  });
}
