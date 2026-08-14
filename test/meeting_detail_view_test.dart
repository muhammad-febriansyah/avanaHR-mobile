import 'package:avanahr/app/data/models/meeting.dart';
import 'package:avanahr/app/data/providers/avana_api.dart';
import 'package:avanahr/app/modules/meeting/meeting_detail_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _FailedMeetingApi extends AvanaApi {
  @override
  Future<MeetingDetail> meeting(int id) async => MeetingDetail.fromJson({
    'id': id,
    'title': 'Buat bisnis plan',
    'status': 'failed',
    'duration_minutes': 12,
    'can_reprocess': true,
    'failure_reason':
        'Ringkasan gagal dibuat. Transkrip tetap tersimpan — coba proses ulang dari detail rapat.',
    'transcript': [
      {
        'timecode': '00:01',
        'start_ms': 1000,
        'speaker': 'Pembicara 1',
        'text': 'Kita mulai rapat.',
      },
    ],
  });
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets(
    'failed summary shows a clear reprocess action beside the error',
    (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => GetMaterialApp(
            home: MeetingDetailView(meetingId: 7, api: _FailedMeetingApi()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final reprocessButton = find.byKey(
        const Key('meeting-summary-reprocess'),
      );

      expect(reprocessButton, findsOneWidget);
      expect(find.text('Buat ulang ringkasan'), findsOneWidget);

      await tester.tap(reprocessButton);
      await tester.pumpAndSettle();

      expect(find.text('Buat ulang ringkasan?'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Buat ulang'), findsOneWidget);
    },
  );
}
