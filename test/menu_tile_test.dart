import 'package:avanahr/app/data/models/user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

/// A slice of a real `/auth/me` body, copied from the running server so the
/// field names are the ones actually sent rather than the ones assumed here.
Map<String, dynamic> _payload(Object? menu) => {
  'id': 18,
  'name': 'Budi Mekanik',
  'email': 'budi.m@bengkel-dinamis.co.id',
  'roles': ['kepala-bengkel'],
  if (menu != null) 'menu': menu,
};

void main() {
  setUpAll(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://127.0.0.1:8000/api/v1',
    );
  });

  group('AppUser Menu Cepat', () {
    test('reads the tiles the server sent, in order', () {
      final user = AppUser.fromJson(
        _payload([
          {
            'key': 'cuti',
            'label': 'Cuti',
            'icon': 'sun_1',
            'color': '#22C55E',
            'route': '/leave',
          },
          {
            'key': 'slip_gaji',
            'label': 'Slip Gaji',
            'icon': 'receipt_2',
            'color': '#0891B2',
            'route': '/payslip',
          },
        ]),
      );

      expect(user.menu.map((t) => t.key).toList(), ['cuti', 'slip_gaji']);
      expect(user.menu.first.label, 'Cuti');
      expect(user.menu.first.icon, 'sun_1');
      expect(user.menu.first.color, '#22C55E');
      expect(user.menu.first.route, '/leave');
    });

    test('a hidden tile simply is not in the list', () {
      // What the server returns once "Kunjungan" is switched off for the role.
      final user = AppUser.fromJson(
        _payload([
          {
            'key': 'cuti',
            'label': 'Cuti',
            'icon': 'sun_1',
            'color': '#22C55E',
            'route': '/leave',
          },
        ]),
      );

      expect(user.menu.map((t) => t.key), isNot(contains('kunjungan')));
      expect(user.menu, hasLength(1));
    });

    test('an admin rename travels with the tile', () {
      final user = AppUser.fromJson(
        _payload([
          {
            'key': 'uang_muka',
            'label': 'Kasbon',
            'icon': 'wallet_add',
            'color': '#7C3AED',
            'route': '/kasbon',
          },
        ]),
      );

      expect(user.menu.single.label, 'Kasbon');
      // The key and route are the app's contract and must survive a rename.
      expect(user.menu.single.key, 'uang_muka');
      expect(user.menu.single.route, '/kasbon');
    });

    test('an older backend that sends no menu leaves the list empty', () {
      // Empty is what makes the home tab fall back to its built-in tiles.
      expect(AppUser.fromJson(_payload(null)).menu, isEmpty);
    });

    test('a malformed tile does not take the whole payload down', () {
      final user = AppUser.fromJson(
        _payload([
          {'key': 'cuti'},
        ]),
      );

      expect(user.menu.single.key, 'cuti');
      expect(user.menu.single.label, '');
      // Falls back to the brand colour rather than crashing on a missing hex.
      expect(user.menu.single.color, '#2F54C9');
    });
  });
}
