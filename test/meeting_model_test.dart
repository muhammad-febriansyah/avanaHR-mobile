import 'package:avanahr/app/data/models/meeting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shapes copied from a real `/me/meetings*` body, so a renamed field on the
/// Laravel side fails here rather than on somebody's phone.
///
/// Note what this file deliberately does NOT do: call
/// `initializeDateFormatting`. A meeting row rendering its date is the exact
/// thing that used to throw inside a list build and leave the whole screen
/// blank with nothing to explain it, so the date formatting is exercised here
/// with the locale data absent.
void main() {
  group('MeetingItem', () {
    test('reads the list payload', () {
      final meeting = MeetingItem.fromJson({
        'id': 7,
        'title': 'Weekly Sync',
        'location': 'Ruang 302',
        'status': 'ready',
        'started_at': '2026-07-30T09:12:00+07:00',
        'duration_ms': 765000,
        'duration_minutes': 13,
        'has_summary': true,
        'participants': ['Rina', 'Bagus'],
      });

      expect(meeting.id, 7);
      expect(meeting.durationMinutes, 13);
      expect(meeting.isReady, isTrue);
      expect(meeting.isWorking, isFalse);
      expect(meeting.statusLabel, 'Siap');
      expect(meeting.participants, ['Rina', 'Bagus']);
    });

    test('formats the start without locale data instead of throwing', () {
      final meeting = MeetingItem.fromJson({
        'id': 1,
        'title': 'Rapat',
        'status': 'ready',
        'started_at': '2026-07-30T09:12:00+07:00',
      });

      // Whatever comes out, it must be a real label and must not blow up.
      expect(() => meeting.startedLabel, returnsNormally);
      expect(meeting.startedLabel, isNotEmpty);
      expect(meeting.startedLabel, contains('2026'));
    });

    test('has no start label when it never started', () {
      final meeting = MeetingItem.fromJson({
        'id': 2,
        'title': 'Rapat',
        'status': 'recording',
      });

      expect(meeting.startedLabel, isEmpty);
      expect(meeting.isWorking, isTrue);
    });
  });

  group('MeetingDetail', () {
    test('reads decisions as a list rather than out of the summary prose', () {
      final detail = MeetingDetail.fromJson({
        'id': 7,
        'title': 'Weekly Sync',
        'status': 'ready',
        'summary': 'Rapat membahas integrasi payroll.',
        'decisions': ['Integrasi jalan bulan depan', 'Vendor dikunci'],
        'can_reprocess': true,
        'action_items': [
          {'id': 1, 'text': 'Kirim notulen', 'status': 'open'},
        ],
        'insights': [],
      });

      expect(detail.decisions, hasLength(2));
      expect(detail.summary, isNot(contains('Keputusan')));
      expect(detail.canReprocess, isTrue);
      expect(detail.hasSummaryContent, isTrue);
    });

    test('treats a meeting with neither summary nor decisions as empty', () {
      final detail = MeetingDetail.fromJson({
        'id': 8,
        'title': 'Rapat',
        'status': 'ready',
      });

      expect(detail.hasSummaryContent, isFalse);
      expect(detail.canReprocess, isFalse);
      expect(detail.insights, isEmpty);
    });

    test('shares the summary and follow-ups but never the transcript', () {
      final detail = MeetingDetail.fromJson({
        'id': 9,
        'title': 'Weekly Sync',
        'status': 'ready',
        'started_at': '2026-07-30T09:12:00+07:00',
        'duration_minutes': 13,
        'summary': 'Rapat membahas integrasi payroll.',
        'decisions': ['Integrasi jalan bulan depan'],
        'action_items': [
          {
            'id': 1,
            'text': 'Kirim notulen',
            'assignee': 'Rina',
            'status': 'done',
          },
        ],
        'transcript': [
          {
            'timecode': '01:05',
            'start_ms': 65000,
            'speaker': 'Rina',
            'text': 'Rahasia yang tidak boleh diteruskan.',
          },
        ],
      });

      final text = detail.shareText;

      expect(text, contains('Weekly Sync'));
      expect(text, contains('integrasi payroll'));
      expect(text, contains('KEPUTUSAN'));
      expect(text, contains('Kirim notulen'));
      expect(text, contains('Rina'));
      // The verbatim record stays out of anything forwarded on.
      expect(text, isNot(contains('Rahasia yang tidak boleh diteruskan')));
    });
  });

  group('MeetingInsight', () {
    test('flattens each analysis shape into readable points', () {
      final risk = MeetingInsight.fromJson({
        'type': 'project_risk',
        'label': 'Risiko Proyek',
        'payload': {
          'risks': [
            {
              'risk': 'Jadwal rilis mepet',
              'severity': 'tinggi',
              'mitigation': 'Tambah reviewer',
            },
          ],
        },
      });

      expect(risk.bullets, hasLength(1));
      expect(risk.bullets.first, contains('Jadwal rilis mepet'));
      expect(risk.bullets.first, contains('risiko tinggi'));

      final followUp = MeetingInsight.fromJson({
        'type': 'follow_up',
        'label': 'Rekomendasi Tindak Lanjut',
        'payload': {
          'recommendations': [
            {'action': 'Kunci vendor', 'owner': 'Finance', 'deadline': 'Jumat'},
          ],
        },
      });

      expect(followUp.bullets.first, 'Kunci vendor · Finance · Jumat');
    });

    test('survives an analysis whose payload is empty or unknown', () {
      final unknown = MeetingInsight.fromJson({
        'type': 'something_new',
        'label': 'Baru',
        'payload': {},
      });

      expect(unknown.bullets, isEmpty);
    });
  });

  group('MeetingSttGrant', () {
    test('builds the listening socket from the params the server chose', () {
      final grant = MeetingSttGrant.fromJson({
        'access_token': 'grant-abc',
        'expires_in': 60,
        'ws_url': 'wss://api.deepgram.com/v1/listen',
        'params': {'model': 'nova-2', 'language': 'id', 'diarize': 'true'},
        'max_minutes': 180,
        'block_ms': 15000,
      });

      expect(grant.uri.host, 'api.deepgram.com');
      expect(grant.uri.queryParameters['diarize'], 'true');
      expect(grant.uri.queryParameters['model'], 'nova-2');
      expect(grant.blockMs, 15000);
    });
  });
}
