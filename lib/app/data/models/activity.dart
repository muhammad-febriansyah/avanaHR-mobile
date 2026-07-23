/// A single entry in the "Riwayat" activity feed (`/me/activities`): an
/// attendance event or a request (leave, overtime, permission, WFH, claim).
class ActivityItem {
  final String type;
  final String title;
  final String subtitle;
  final String? status;
  final DateTime? occurredAt;

  /// Extra fields for a detail view (currently only attendance carries it).
  final Map<String, dynamic>? detail;

  const ActivityItem({
    required this.type,
    required this.title,
    required this.subtitle,
    this.status,
    this.occurredAt,
    this.detail,
  });

  bool get hasDetail => detail != null && detail!.isNotEmpty;

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    final raw = json['occurred_at'];

    return ActivityItem(
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      status: json['status'] as String?,
      occurredAt: raw is String ? DateTime.tryParse(raw) : null,
      detail: json['detail'] is Map
          ? Map<String, dynamic>.from(json['detail'] as Map)
          : null,
    );
  }
}
