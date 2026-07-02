// Employee self-service models for the AvanaHR mobile API (all {data}-enveloped).

class LeaveType {
  final int id;
  final String code;
  final String name;
  final int defaultQuota;
  final bool requiresAttachment;

  LeaveType({required this.id, required this.code, required this.name, required this.defaultQuota, required this.requiresAttachment});

  factory LeaveType.fromJson(Map<String, dynamic> j) => LeaveType(
        id: j['id'],
        code: j['code'] ?? '',
        name: j['name'] ?? '',
        defaultQuota: (j['default_quota'] ?? 0) is int ? j['default_quota'] : int.tryParse('${j['default_quota']}') ?? 0,
        requiresAttachment: j['requires_attachment'] ?? false,
      );
}

class LeaveRequestItem {
  final int id;
  final String? leaveType;
  final String startDate;
  final String endDate;
  final int totalDays;
  final String? reason;
  final String status;

  LeaveRequestItem({required this.id, required this.startDate, required this.endDate, required this.totalDays, required this.status, this.leaveType, this.reason});

  factory LeaveRequestItem.fromJson(Map<String, dynamic> j) => LeaveRequestItem(
        id: j['id'],
        leaveType: j['leave_type'],
        startDate: j['start_date'] ?? '',
        endDate: j['end_date'] ?? '',
        totalDays: (j['total_days'] ?? 0) is int ? j['total_days'] : int.tryParse('${j['total_days']}') ?? 0,
        reason: j['reason'],
        status: j['status'] ?? '',
      );
}

class OvertimeItem {
  final int id;
  final String date;
  final double hours;
  final String? reason;
  final String status;

  OvertimeItem({required this.id, required this.date, required this.hours, required this.status, this.reason});

  factory OvertimeItem.fromJson(Map<String, dynamic> j) => OvertimeItem(
        id: j['id'],
        date: j['date'] ?? '',
        hours: (j['hours'] ?? 0).toDouble(),
        reason: j['reason'],
        status: j['status'] ?? '',
      );
}

class PermissionItem {
  final int id;
  final String date;
  final String type;
  final String? startTime;
  final String? endTime;
  final String? reason;
  final String status;

  PermissionItem({required this.id, required this.date, required this.type, required this.status, this.startTime, this.endTime, this.reason});

  factory PermissionItem.fromJson(Map<String, dynamic> j) => PermissionItem(
        id: j['id'],
        date: j['date'] ?? '',
        type: j['type'] ?? '',
        startTime: j['start_time'],
        endTime: j['end_time'],
        reason: j['reason'],
        status: j['status'] ?? '',
      );
}

class WfhItem {
  final int id;
  final String startDate;
  final String endDate;
  final String? reason;
  final String status;

  WfhItem({required this.id, required this.startDate, required this.endDate, required this.status, this.reason});

  factory WfhItem.fromJson(Map<String, dynamic> j) => WfhItem(
        id: j['id'],
        startDate: j['start_date'] ?? '',
        endDate: j['end_date'] ?? '',
        reason: j['reason'],
        status: j['status'] ?? '',
      );
}

class ReimbursementItem {
  final int id;
  final String category;
  final String? title;
  final int amount;
  final String date;
  final String status;

  ReimbursementItem({required this.id, required this.category, required this.amount, required this.date, required this.status, this.title});

  factory ReimbursementItem.fromJson(Map<String, dynamic> j) => ReimbursementItem(
        id: j['id'],
        category: j['category'] ?? '',
        title: j['title'],
        amount: (j['amount'] ?? 0) is int ? j['amount'] : int.tryParse('${j['amount']}') ?? 0,
        date: j['date'] ?? '',
        status: j['status'] ?? '',
      );
}

class AnnouncementItem {
  final int id;
  final String title;
  final String? body;
  final String? category;
  final bool pinned;
  final String? publishedAt;

  AnnouncementItem({required this.id, required this.title, required this.pinned, this.body, this.category, this.publishedAt});

  factory AnnouncementItem.fromJson(Map<String, dynamic> j) => AnnouncementItem(
        id: j['id'],
        title: j['title'] ?? '',
        body: j['body'],
        category: j['category'],
        pinned: j['pinned'] ?? false,
        publishedAt: j['published_at'],
      );
}
