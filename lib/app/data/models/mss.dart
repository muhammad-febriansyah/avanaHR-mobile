import 'dart:ui';

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

Color _hex(dynamic value) {
  final s = (value ?? '#2F54C9').toString().replaceAll('#', '');
  final v = int.tryParse(s.length == 6 ? 'FF$s' : s, radix: 16) ?? 0xFF2F54C9;
  return Color(v);
}
