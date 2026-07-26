import 'package:avanahr/app/data/models/user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _payload(Map<String, dynamic>? tenant) => {
  'id': 7,
  'name': 'Bagus Pratama',
  'email': 'bagus@example.test',
  'roles': ['employee'],
  'tenant': tenant,
};

void main() {
  setUpAll(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://127.0.0.1:8000/api/v1',
    );
  });

  group('AppUser tenant branding', () {
    test('splits the short brand name from the legal company name', () {
      final user = AppUser.fromJson(
        _payload({
          'id': 1,
          'name': 'avanahR',
          'company_name': 'PT Avanah Digital Teknologi',
          'logo_url': '/storage/company/logo.png',
        }),
      );

      expect(user.tenantBrandName, 'avanahR');
      expect(user.tenantName, 'PT Avanah Digital Teknologi');
      expect(
        user.tenantLogoUrl,
        'http://127.0.0.1:8000/storage/company/logo.png',
      );
    });

    test('falls back to the tenant name when company_name is missing', () {
      final user = AppUser.fromJson(
        _payload({'id': 1, 'name': 'avanahR', 'company_name': null}),
      );

      expect(user.tenantBrandName, 'avanahR');
      expect(user.tenantName, 'avanahR');
      expect(user.tenantLogoUrl, isNull);
    });

    test('leaves branding null when the payload has no tenant', () {
      final user = AppUser.fromJson(_payload(null));

      expect(user.tenantBrandName, isNull);
      expect(user.tenantName, isNull);
      expect(user.tenantLogoUrl, isNull);
    });
  });
}
