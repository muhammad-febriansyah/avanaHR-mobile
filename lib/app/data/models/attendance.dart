class AttendanceToday {
  final String date;
  final String? clockIn;
  final String? clockOut;
  final String nextAction; // 'in' or 'out'
  final String? status;
  final int workMinutes;

  AttendanceToday({
    required this.date,
    required this.nextAction,
    this.clockIn,
    this.clockOut,
    this.status,
    this.workMinutes = 0,
  });

  bool get canClockIn => nextAction == 'in';

  factory AttendanceToday.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'];
    return AttendanceToday(
      date: json['date'] ?? '',
      clockIn: json['clock_in'],
      clockOut: json['clock_out'],
      nextAction: json['next_action'] ?? 'in',
      status: summary is Map ? summary['status'] : null,
      workMinutes: summary is Map ? (summary['work_minutes'] ?? 0) : 0,
    );
  }
}
