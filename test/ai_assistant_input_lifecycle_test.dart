import 'package:avanahr/app/modules/ai_assistant/ai_assistant_controller.dart';
import 'package:avanahr/app/modules/ai_assistant/ai_assistant_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

class _TestAiAssistantController extends AiAssistantController {
  String? sentMessage;

  @override
  Future<void> loadSession() async {
    isLoading.value = false;
    ready.value = true;
  }

  @override
  Future<void> send(String text) async {
    sentMessage = text;
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('composer owns and disposes its input with the page', (
    tester,
  ) async {
    final controller =
        Get.put<AiAssistantController>(_TestAiAssistantController())
            as _TestAiAssistantController;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => const GetMaterialApp(home: AiAssistantView()),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Cek saldo cuti');
    await tester.tap(find.byIcon(Iconsax.send_1));
    await tester.pump();

    expect(controller.sentMessage, 'Cek saldo cuti');
    expect(find.text('Cek saldo cuti'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
