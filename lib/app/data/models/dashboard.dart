/// A work location with its geofence radius, used to auto-detect whether the
/// employee is inside an office area.
class WorkLocationItem {
  final int id;
  final String name;
  final double? latitude;
  final double? longitude;
  final int radius;

  const WorkLocationItem({
    required this.id,
    required this.name,
    required this.radius,
    this.latitude,
    this.longitude,
  });

  factory WorkLocationItem.fromJson(Map<String, dynamic> j) => WorkLocationItem(
        id: j['id'] ?? 0,
        name: (j['name'] ?? '').toString(),
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        radius: (j['radius'] ?? 0) is int ? j['radius'] : int.tryParse('${j['radius']}') ?? 0,
      );
}

/// Compact home dashboard summary from `/me/dashboard`.
class DashboardSummary {
  final double leaveAvailable;
  final int workMinutesMonth;
  final double workHoursMonth;
  final int pendingCount;

  const DashboardSummary({
    required this.leaveAvailable,
    required this.workMinutesMonth,
    required this.workHoursMonth,
    required this.pendingCount,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> j) => DashboardSummary(
        leaveAvailable: (j['leave_available'] as num?)?.toDouble() ?? 0,
        workMinutesMonth: (j['work_minutes_month'] ?? 0) is int ? j['work_minutes_month'] : 0,
        workHoursMonth: (j['work_hours_month'] as num?)?.toDouble() ?? 0,
        pendingCount: (j['pending_count'] ?? 0) is int ? j['pending_count'] : 0,
      );
}
