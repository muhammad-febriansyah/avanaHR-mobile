class TrackingSessionState {
  final int id;
  final int attendanceId;
  final String status;
  final String startedAt;
  final String? endedAt;
  final String? lastLocationAt;
  final int totalDistanceMeters;

  const TrackingSessionState({
    required this.id,
    required this.attendanceId,
    required this.status,
    required this.startedAt,
    required this.totalDistanceMeters,
    this.endedAt,
    this.lastLocationAt,
  });

  bool get isActive => status == 'active';

  factory TrackingSessionState.fromJson(Map<String, dynamic> json) {
    return TrackingSessionState(
      id: (json['id'] as num).toInt(),
      attendanceId: (json['attendance_id'] as num).toInt(),
      status: json['status']?.toString() ?? 'active',
      startedAt: json['started_at']?.toString() ?? '',
      endedAt: json['ended_at']?.toString(),
      lastLocationAt: json['last_location_at']?.toString(),
      totalDistanceMeters:
          (json['total_distance_meters'] as num?)?.toInt() ?? 0,
    );
  }
}

class TrackingPoint {
  final String clientUuid;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final bool isMocked;
  final int? batteryLevel;
  final String recordedAt;

  const TrackingPoint({
    required this.clientUuid,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.recordedAt,
    this.altitude,
    this.speed,
    this.heading,
    this.isMocked = false,
    this.batteryLevel,
  });

  Map<String, dynamic> toJson() => {
    'client_uuid': clientUuid,
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    if (altitude != null) 'altitude': altitude,
    if (speed != null && speed! >= 0) 'speed': speed,
    if (heading != null && heading! >= 0) 'heading': heading,
    'is_mocked': isMocked,
    if (batteryLevel != null) 'battery_level': batteryLevel,
    'recorded_at': recordedAt,
  };

  factory TrackingPoint.fromJson(Map<String, dynamic> json) => TrackingPoint(
    clientUuid: json['client_uuid'].toString(),
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    accuracy: (json['accuracy'] as num).toDouble(),
    altitude: (json['altitude'] as num?)?.toDouble(),
    speed: (json['speed'] as num?)?.toDouble(),
    heading: (json['heading'] as num?)?.toDouble(),
    isMocked: json['is_mocked'] == true,
    batteryLevel: (json['battery_level'] as num?)?.toInt(),
    recordedAt: json['recorded_at'].toString(),
  );
}
