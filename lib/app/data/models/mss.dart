import 'dart:ui';

import 'dashboard.dart';

/// One pending request routed to the manager (leave / overtime / permission /
/// WFH) in the Manager Self-Service approvals list.
class MssApproval {
  final String id; // composite key e.g. "leave-12"
  final String type;
  final String typeLabel;
  final String employeeName;
  final String initials;
  final Color avatarColor;
  final String? employeeNumber;
  final String title;
  final String detail;
  final String? reason;
  final String? requestedAt;
  final String? status;
  final String? decidedAt;

  const MssApproval({
    required this.id,
    required this.type,
    required this.typeLabel,
    required this.employeeName,
    required this.initials,
    required this.avatarColor,
    required this.title,
    required this.detail,
    this.employeeNumber,
    this.reason,
    this.requestedAt,
    this.status,
    this.decidedAt,
  });

  factory MssApproval.fromJson(Map<String, dynamic> j) {
    final emp = j['employee'] as Map<String, dynamic>?;
    return MssApproval(
      id: (j['id'] ?? '').toString(),
      type: (j['type'] ?? '').toString(),
      typeLabel: (j['type_label'] ?? '').toString(),
      employeeName: (emp?['name'] ?? '—').toString(),
      initials: (emp?['initials'] ?? '?').toString(),
      avatarColor: _hex(emp?['avatar_color']),
      employeeNumber: emp?['employee_number']?.toString(),
      title: (j['title'] ?? '').toString(),
      detail: (j['detail'] ?? '').toString(),
      reason: j['reason']?.toString(),
      requestedAt: j['requested_at']?.toString(),
      status: j['status']?.toString(),
      decidedAt: j['decided_at']?.toString(),
    );
  }
}

/// A member of the manager's team.
class MssTeamMember {
  final int id;
  final String name;
  final String? employeeNumber;
  final String? position;
  final String? department;
  final String status;
  final String initials;
  final Color avatarColor;

  const MssTeamMember({
    required this.id,
    required this.name,
    required this.status,
    required this.initials,
    required this.avatarColor,
    this.employeeNumber,
    this.position,
    this.department,
  });

  factory MssTeamMember.fromJson(Map<String, dynamic> j) => MssTeamMember(
        id: j['id'] ?? 0,
        name: (j['name'] ?? '—').toString(),
        employeeNumber: j['employee_number']?.toString(),
        position: j['position']?.toString(),
        department: j['department']?.toString(),
        status: (j['status'] ?? 'active').toString(),
        initials: (j['initials'] ?? '?').toString(),
        avatarColor: _hex(j['avatar_color']),
      );
}

/// A team member's detail for the manager: profile, this month's attendance
/// recap, today's shift, and their pending requests.
class MssMemberDetail {
  final MssTeamMember member;
  final AttendanceRecap attendance;
  final TodayShift? todayShift;
  final List<MssPendingItem> pending;

  const MssMemberDetail({
    required this.member,
    required this.attendance,
    required this.pending,
    this.todayShift,
  });

  factory MssMemberDetail.fromJson(Map<String, dynamic> j) => MssMemberDetail(
        member: MssTeamMember.fromJson(Map<String, dynamic>.from(j['member'] ?? {})),
        attendance: AttendanceRecap.fromJson(Map<String, dynamic>.from(j['attendance'] ?? {})),
        todayShift: j['today_shift'] is Map
            ? TodayShift.fromJson(Map<String, dynamic>.from(j['today_shift']))
            : null,
        pending: ((j['pending'] as List?) ?? [])
            .map((e) => MssPendingItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// A member's attendance tally for the current month.
class AttendanceRecap {
  final String month;
  final int present;
  final int late;
  final int absent;
  final double workHours;

  const AttendanceRecap({
    required this.month,
    required this.present,
    required this.late,
    required this.absent,
    required this.workHours,
  });

  factory AttendanceRecap.fromJson(Map<String, dynamic> j) => AttendanceRecap(
        month: (j['month'] ?? '').toString(),
        present: (j['present'] ?? 0) is int ? j['present'] : 0,
        late: (j['late'] ?? 0) is int ? j['late'] : 0,
        absent: (j['absent'] ?? 0) is int ? j['absent'] : 0,
        workHours: (j['work_hours'] as num?)?.toDouble() ?? 0,
      );
}

/// A compact pending request shown on the member detail (context, not actionable).
class MssPendingItem {
  final String id;
  final String type;
  final String typeLabel;
  final String title;
  final String detail;

  const MssPendingItem({
    required this.id,
    required this.type,
    required this.typeLabel,
    required this.title,
    required this.detail,
  });

  factory MssPendingItem.fromJson(Map<String, dynamic> j) => MssPendingItem(
        id: (j['id'] ?? '').toString(),
        type: (j['type'] ?? '').toString(),
        typeLabel: (j['type_label'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        detail: (j['detail'] ?? '').toString(),
      );
}

/// A shift a manager can assign to a team member.
class ShiftOption {
  final int id;
  final String name;
  final String? code;
  final String? start;
  final String? end;

  const ShiftOption({
    required this.id,
    required this.name,
    this.code,
    this.start,
    this.end,
  });

  factory ShiftOption.fromJson(Map<String, dynamic> j) => ShiftOption(
        id: j['id'] ?? 0,
        name: (j['name'] ?? '').toString(),
        code: j['code']?.toString(),
        start: j['start']?.toString(),
        end: j['end']?.toString(),
      );

  String get label {
    final time = (start != null && end != null) ? ' · $start–$end' : '';
    return '$name$time';
  }
}

/// One team member's attendance tally over the recap period.
class TeamRecapRow {
  final int id;
  final String name;
  final String? employeeNumber;
  final String initials;
  final Color avatarColor;
  final int present;
  final int late;
  final int absent;
  final int leave;
  final int wfh;
  final int holiday;
  final double workHours;
  final int lateMinutes;

  const TeamRecapRow({
    required this.id,
    required this.name,
    required this.initials,
    required this.avatarColor,
    required this.present,
    required this.late,
    required this.absent,
    required this.leave,
    required this.wfh,
    required this.holiday,
    required this.workHours,
    required this.lateMinutes,
    this.employeeNumber,
  });

  factory TeamRecapRow.fromJson(Map<String, dynamic> j) => TeamRecapRow(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '—').toString(),
        employeeNumber: j['employee_number']?.toString(),
        initials: (j['initials'] ?? '?').toString(),
        avatarColor: _hex(j['avatar_color']),
        present: (j['present'] as num?)?.toInt() ?? 0,
        late: (j['late'] as num?)?.toInt() ?? 0,
        absent: (j['absent'] as num?)?.toInt() ?? 0,
        leave: (j['leave'] as num?)?.toInt() ?? 0,
        wfh: (j['wfh'] as num?)?.toInt() ?? 0,
        holiday: (j['holiday'] as num?)?.toInt() ?? 0,
        workHours: (j['work_hours'] as num?)?.toDouble() ?? 0,
        lateMinutes: (j['late_minutes'] as num?)?.toInt() ?? 0,
      );
}

/// Team-wide totals for the recap period.
class TeamRecapSummary {
  final int members;
  final int present;
  final int late;
  final int absent;
  final int leave;
  final int wfh;
  final int holiday;
  final double workHours;
  final int lateMinutes;

  const TeamRecapSummary({
    required this.members,
    required this.present,
    required this.late,
    required this.absent,
    required this.leave,
    required this.wfh,
    required this.holiday,
    required this.workHours,
    required this.lateMinutes,
  });

  factory TeamRecapSummary.fromJson(Map<String, dynamic> j) => TeamRecapSummary(
        members: (j['members'] as num?)?.toInt() ?? 0,
        present: (j['present'] as num?)?.toInt() ?? 0,
        late: (j['late'] as num?)?.toInt() ?? 0,
        absent: (j['absent'] as num?)?.toInt() ?? 0,
        leave: (j['leave'] as num?)?.toInt() ?? 0,
        wfh: (j['wfh'] as num?)?.toInt() ?? 0,
        holiday: (j['holiday'] as num?)?.toInt() ?? 0,
        workHours: (j['work_hours'] as num?)?.toDouble() ?? 0,
        lateMinutes: (j['late_minutes'] as num?)?.toInt() ?? 0,
      );
}

/// The manager's team attendance recap: per-member rows plus a period summary.
class TeamRecap {
  final List<TeamRecapRow> rows;
  final String start;
  final String end;
  final TeamRecapSummary summary;

  const TeamRecap({
    required this.rows,
    required this.start,
    required this.end,
    required this.summary,
  });

  factory TeamRecap.fromJson(Map<String, dynamic> j) {
    final meta = Map<String, dynamic>.from(j['meta'] ?? {});
    return TeamRecap(
      rows: ((j['data'] as List?) ?? [])
          .map((e) => TeamRecapRow.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      start: (meta['start'] ?? '').toString(),
      end: (meta['end'] ?? '').toString(),
      summary:
          TeamRecapSummary.fromJson(Map<String, dynamic>.from(meta['summary'] ?? {})),
    );
  }
}

Color _hex(dynamic value) {
  final s = (value ?? '#2F54C9').toString().replaceAll('#', '');
  final v = int.tryParse(s.length == 6 ? 'FF$s' : s, radix: 16) ?? 0xFF2F54C9;
  return Color(v);
}
