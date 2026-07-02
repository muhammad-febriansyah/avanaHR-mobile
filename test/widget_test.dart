import 'package:avanahr/app/routes/app_pages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('face routes are registered', () {
    final names = AppPages.routes.map((r) => r.name).toList();
    expect(names, contains(Routes.FACE_ENROLL));
    expect(names, contains(Routes.FACE_VERIFY));
  });
}
