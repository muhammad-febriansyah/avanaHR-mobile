// Employee self-service models for the AvanaHR mobile API (all {data}-enveloped).

import '../../core/config/env.dart';

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

class DocumentItem {
  final int id;
  final String name;
  final String? type;
  final String? url;
  final int size;
  final String? uploadedAt;

  DocumentItem({required this.id, required this.name, required this.size, this.type, this.url, this.uploadedAt});

  factory DocumentItem.fromJson(Map<String, dynamic> j) => DocumentItem(
        id: j['id'],
        name: j['name'] ?? '',
        type: j['type'],
        url: j['url'],
        size: (j['size'] ?? 0) is int ? j['size'] : int.tryParse('${j['size']}') ?? 0,
        uploadedAt: j['uploaded_at'],
      );
}

class FieldVisitItem {
  final int id;
  final String visitDate;
  final String location;
  final String? clientName;
  final String? purpose;
  final String? notes;
  final String? photoUrl;
  final String status;

  FieldVisitItem({
    required this.id,
    required this.visitDate,
    required this.location,
    required this.status,
    this.clientName,
    this.purpose,
    this.notes,
    this.photoUrl,
  });

  factory FieldVisitItem.fromJson(Map<String, dynamic> j) => FieldVisitItem(
        id: j['id'],
        visitDate: j['visit_date'] ?? '',
        location: j['location'] ?? '',
        clientName: j['client_name'],
        purpose: j['purpose'],
        notes: j['notes'],
        photoUrl: Env.resolveMedia(j['photo_url'] as String?),
        status: j['status'] ?? '',
      );
}

class ShiftSwapItem {
  final int id;
  final String date;
  final String? requester;
  final String? target;
  final String direction;
  final String? reason;
  final String status;

  ShiftSwapItem({
    required this.id,
    required this.date,
    required this.direction,
    required this.status,
    this.requester,
    this.target,
    this.reason,
  });

  factory ShiftSwapItem.fromJson(Map<String, dynamic> j) => ShiftSwapItem(
        id: j['id'],
        date: j['date'] ?? '',
        requester: j['requester'],
        target: j['target'],
        direction: j['direction'] ?? 'outgoing',
        reason: j['reason'],
        status: j['status'] ?? '',
      );
}

class Colleague {
  final int id;
  final String name;
  final String? employeeNumber;

  Colleague({required this.id, required this.name, this.employeeNumber});

  factory Colleague.fromJson(Map<String, dynamic> j) => Colleague(
        id: j['id'],
        name: j['name'] ?? '',
        employeeNumber: j['employee_number'],
      );
}
