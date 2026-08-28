import 'dart:convert';

import 'package:get_storage/get_storage.dart';

import '../models/tracking.dart';

/// Owner-scoped durable GPS queue. GetStorage is already the app's offline
/// persistence layer, so V1 adds no database dependency merely for buffering.
class TrackingQueueRepository {
  final GetStorage _box;

  TrackingQueueRepository({GetStorage? box}) : _box = box ?? GetStorage();

  String _key(String owner) => 'tracking_queue_$owner';

  List<TrackingPoint> read(String owner) {
    final raw = _box.read<String>(_key(owner));
    if (raw == null || raw.isEmpty) return [];

    try {
      return (jsonDecode(raw) as List)
          .map(
            (entry) =>
                TrackingPoint.fromJson(Map<String, dynamic>.from(entry as Map)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  void append(String owner, TrackingPoint point) {
    final points = read(owner)..add(point);
    _write(owner, points);
  }

  void remove(String owner, Iterable<String> clientUuids) {
    final synced = clientUuids.toSet();
    _write(
      owner,
      read(owner).where((point) => !synced.contains(point.clientUuid)).toList(),
    );
  }

  void _write(String owner, List<TrackingPoint> points) {
    _box.write(
      _key(owner),
      jsonEncode(points.map((point) => point.toJson()).toList()),
    );
  }
}
