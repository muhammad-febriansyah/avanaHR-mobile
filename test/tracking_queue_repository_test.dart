import 'dart:io';

import 'package:avanahr/app/data/models/tracking.dart';
import 'package:avanahr/app/data/services/tracking_queue_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('avanahr_tracking_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => temp.path,
        );
    await GetStorage.init();
    await GetStorage().erase();
  });

  tearDown(() async {
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  test('keeps offline points owner scoped and removes only synced UUIDs', () {
    final repository = TrackingQueueRepository();
    const first = TrackingPoint(
      clientUuid: '01916bb5-0ef8-4c26-b9da-c368c8b5ab36',
      latitude: -6.2146,
      longitude: 106.8451,
      accuracy: 8,
      recordedAt: '2026-08-14T08:30:10Z',
    );
    const second = TrackingPoint(
      clientUuid: '87c10ee7-b25d-48d2-b76f-b5fd1b7292da',
      latitude: -6.2155,
      longitude: 106.8451,
      accuracy: 7,
      recordedAt: '2026-08-14T08:30:30Z',
    );

    repository.append('tenant-a:employee-1', first);
    repository.append('tenant-a:employee-1', second);
    repository.append('tenant-b:employee-2', first);

    expect(repository.read('tenant-a:employee-1'), hasLength(2));
    expect(repository.read('tenant-b:employee-2'), hasLength(1));

    repository.remove('tenant-a:employee-1', [first.clientUuid]);

    expect(
      repository.read('tenant-a:employee-1').single.clientUuid,
      second.clientUuid,
    );
    expect(repository.read('tenant-b:employee-2'), hasLength(1));
  });

  test('tracking session restores the active API shape', () {
    final state = TrackingSessionState.fromJson({
      'id': 991,
      'attendance_id': 123,
      'status': 'active',
      'started_at': '2026-08-14T08:02:00+07:00',
      'total_distance_meters': 8420,
    });

    expect(state.isActive, isTrue);
    expect(state.id, 991);
    expect(state.totalDistanceMeters, 8420);
  });
}
