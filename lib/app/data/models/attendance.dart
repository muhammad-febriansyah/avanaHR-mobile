class AttendanceToday {
  final String date;
  final String? workDate;
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

  /// Tenant face enforcement: 'block' refuses a punch whose face was never
  /// captured or does not match; 'flag' records the punch and marks it for
  /// review instead. From `requirements.face_enforcement`.
  final String faceEnforcement;

  /// Whether "1 device 1 account" binding is enforced by the tenant.
  final bool deviceBindingEnabled;

  /// Whether a punch must carry a single-use liveness nonce. The server hands
  /// one out from `/me/attendance/challenge` and rejects a clock without it,
  /// so this decides whether to fetch one before submitting.
  final bool requiresLivenessChallenge;

  /// Whether the tenant makes face enrolment a precondition for clocking. When
  /// off, someone who has not enrolled may still clock — the server skips the
  /// identity match rather than refusing the punch.
  final bool requiresFaceEnrollment;

  /// The wall clock the tenant works to (IANA name), and its Indonesian
  /// label. Times in the response are already read on this clock; the label
  /// is what the screen puts next to them so "08:00" says which 08:00.
  final String timezone;
  final String timezoneLabel;

  /// True while one or more punches only exist in the device queue.
  final bool pendingSync;

  AttendanceToday({
    required this.date,
    required this.nextAction,
    this.workDate,
    this.clockIn,
    this.clockOut,
    this.clockInAt,
    this.status,
    this.workMinutes = 0,
    this.workMode,
    this.wfhApprovedToday = false,
    this.faceMode = 'recognition',
    this.faceEnforcement = 'block',
    this.deviceBindingEnabled = true,
    this.requiresLivenessChallenge = false,
    this.requiresFaceEnrollment = false,
    this.timezone = 'Asia/Jakarta',
    this.timezoneLabel = 'WIB',
    this.pendingSync = false,
  });

  /// Indonesia keeps no daylight saving, so each zone is a fixed offset and
  /// the app can read the tenant's wall clock without a timezone database.
  int get _tenantOffsetHours => switch (timezone) {
    'Asia/Makassar' => 8,
    'Asia/Jayapura' => 9,
    _ => 7,
  };

  /// Now, on the tenant's wall clock rather than the phone's. A phone set to
  /// WIB inside a WITA company must not show — or optimistically record — an
  /// hour that the office never saw.
  DateTime nowOnTenantClock() =>
      DateTime.now().toUtc().add(Duration(hours: _tenantOffsetHours));

  /// A live face must be captured at clock-in (recognition or detection).
  bool get requiresFaceCapture => faceMode != 'off';

  /// The captured face is identity-matched against the enrolled template.
  bool get usesFaceRecognition => faceMode == 'recognition';

  /// Whether a missing or unmatched face refuses the punch outright. When false
  /// the tenant only wants it flagged, so the app must not be stricter than the
  /// server and strand the employee at the camera.
  bool get blocksOnFaceFailure => faceEnforcement != 'flag';

  bool get canClockIn => nextAction == 'in';

  /// The server reports 'done' once both clocks are recorded; the button must
  /// stop offering a clock-out the server would reject.
  bool get isDone => nextAction == 'done';

  factory AttendanceToday.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic> requirements = const {},
  }) {
    final summary = json['summary'];
    final rawStatus = summary is Map
        ? summary['status']?.toString().trim().toLowerCase()
        : null;
    return AttendanceToday(
      date: json['date'] ?? '',
      workDate: json['work_date']?.toString(),
      clockIn: json['clock_in'],
      clockOut: json['clock_out'],
      clockInAt: json['clock_in_at'],
      nextAction: json['next_action']?.toString().trim().toLowerCase() ?? 'in',
      status: rawStatus == null || rawStatus.isEmpty ? null : rawStatus,
      workMinutes: summary is Map ? (summary['work_minutes'] ?? 0) : 0,
      workMode: json['work_mode'],
      wfhApprovedToday: requirements['wfh_approved_today'] == true,
      faceMode: (requirements['face_mode'] as String?) ?? 'recognition',
      faceEnforcement: (requirements['face_enforcement'] as String?) ?? 'block',
      deviceBindingEnabled: requirements['device_binding_enabled'] != false,
      requiresLivenessChallenge:
          requirements['require_liveness_challenge'] == true,
      requiresFaceEnrollment: requirements['require_face_enrollment'] == true,
      timezone: (requirements['timezone'] as String?) ?? 'Asia/Jakarta',
      timezoneLabel: (requirements['timezone_label'] as String?) ?? 'WIB',
      pendingSync: json['pending_sync'] == true,
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'date': date,
    'work_date': workDate,
    'clock_in': clockIn,
    'clock_out': clockOut,
    'clock_in_at': clockInAt,
    'next_action': nextAction,
    'summary': {'status': status, 'work_minutes': workMinutes},
    'work_mode': workMode,
    'pending_sync': pendingSync,
    'requirements': {
      'wfh_approved_today': wfhApprovedToday,
      'face_mode': faceMode,
      'face_enforcement': faceEnforcement,
      'device_binding_enabled': deviceBindingEnabled,
      'require_liveness_challenge': requiresLivenessChallenge,
      'require_face_enrollment': requiresFaceEnrollment,
      'timezone': timezone,
      'timezone_label': timezoneLabel,
    },
  };

  AttendanceToday copyWith({
    String? date,
    String? workDate,
    String? clockIn,
    String? clockOut,
    String? clockInAt,
    String? nextAction,
    String? status,
    int? workMinutes,
    String? workMode,
    bool? pendingSync,
  }) => AttendanceToday(
    date: date ?? this.date,
    workDate: workDate ?? this.workDate,
    clockIn: clockIn ?? this.clockIn,
    clockOut: clockOut ?? this.clockOut,
    clockInAt: clockInAt ?? this.clockInAt,
    nextAction: nextAction ?? this.nextAction,
    status: status ?? this.status,
    workMinutes: workMinutes ?? this.workMinutes,
    workMode: workMode ?? this.workMode,
    wfhApprovedToday: wfhApprovedToday,
    faceMode: faceMode,
    faceEnforcement: faceEnforcement,
    deviceBindingEnabled: deviceBindingEnabled,
    requiresLivenessChallenge: requiresLivenessChallenge,
    requiresFaceEnrollment: requiresFaceEnrollment,
    timezone: timezone,
    timezoneLabel: timezoneLabel,
    pendingSync: pendingSync ?? this.pendingSync,
  );
}
