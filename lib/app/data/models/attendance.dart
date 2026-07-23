class AttendanceToday {
  final String date;
  final String? clockIn;
  final String? clockOut;

  /// Full ISO clock-in timestamp (with seconds), for the live worked-hours
  /// ticker. Null until clocked in.
  final String? clockInAt;
  final String nextAction; // 'in' or 'out'
  final String? status;
  final int workMinutes;

  /// Mode the day was clocked in under ('office' or 'home'); null until then.
  final String? workMode;

  /// Whether an approved WFH request covers today — the licence for picking
  /// "home". Comes from the response's `requirements`, not its `data`.
  final bool wfhApprovedToday;

  /// Tenant face policy: 'recognition' (1:1 match), 'detection' (live face
  /// only, no match), or 'off' (no face check). From `requirements.face_mode`.
  final String faceMode;

  /// Whether "1 device 1 account" binding is enforced by the tenant.
  final bool deviceBindingEnabled;

  AttendanceToday({
    required this.date,
    required this.nextAction,
    this.clockIn,
    this.clockOut,
    this.clockInAt,
    this.status,
    this.workMinutes = 0,
    this.workMode,
    this.wfhApprovedToday = false,
    this.faceMode = 'recognition',
    this.deviceBindingEnabled = true,
  });

  /// A live face must be captured at clock-in (recognition or detection).
  bool get requiresFaceCapture => faceMode != 'off';

  /// The captured face is identity-matched against the enrolled template.
  bool get usesFaceRecognition => faceMode == 'recognition';

  bool get canClockIn => nextAction == 'in';

  factory AttendanceToday.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic> requirements = const {},
  }) {
    final summary = json['summary'];
    return AttendanceToday(
      date: json['date'] ?? '',
      clockIn: json['clock_in'],
      clockOut: json['clock_out'],
      clockInAt: json['clock_in_at'],
      nextAction: json['next_action'] ?? 'in',
      status: summary is Map ? summary['status'] : null,
      workMinutes: summary is Map ? (summary['work_minutes'] ?? 0) : 0,
      workMode: json['work_mode'],
      wfhApprovedToday: requirements['wfh_approved_today'] == true,
      faceMode: (requirements['face_mode'] as String?) ?? 'recognition',
      deviceBindingEnabled: requirements['device_binding_enabled'] != false,
    );
  }
}
