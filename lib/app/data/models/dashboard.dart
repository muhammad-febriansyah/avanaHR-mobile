import 'dart:ui';

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
    radius: (j['radius'] ?? 0) is int
        ? j['radius']
        : int.tryParse('${j['radius']}') ?? 0,
  );
}

/// Compact home dashboard summary from `/me/dashboard`.
class DashboardSummary {
  final double leaveAvailable;
  final int workMinutesMonth;
  final double workHoursMonth;
  final int pendingCount;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final TodayShift? todayShift;

  /// A preview slice of the colleagues celebrating a birthday today — the API
  /// caps it, since the banner only draws a few faces. Scoped to the caller's
  /// tenant server-side; the app never filters it further.
  final List<BirthdayPerson> birthdays;

  /// How many people are actually celebrating, which is what the headline
  /// counts. Equal to `birthdays.length` until the preview cap kicks in.
  final int birthdaysTotal;

  const DashboardSummary({
    required this.leaveAvailable,
    required this.workMinutesMonth,
    required this.workHoursMonth,
    required this.pendingCount,
    this.presentDays = 0,
    this.absentDays = 0,
    this.lateDays = 0,
    this.todayShift,
    this.birthdays = const [],
    this.birthdaysTotal = 0,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> j) {
    final att = j['attendance_month'];
    final m = att is Map
        ? Map<String, dynamic>.from(att)
        : const <String, dynamic>{};
    final birthdays = ((j['birthdays'] as List?) ?? [])
        .map((e) => BirthdayPerson.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return DashboardSummary(
      leaveAvailable: (j['leave_available'] as num?)?.toDouble() ?? 0,
      workMinutesMonth: (j['work_minutes_month'] ?? 0) is int
          ? j['work_minutes_month']
          : 0,
      workHoursMonth: (j['work_hours_month'] as num?)?.toDouble() ?? 0,
      pendingCount: (j['pending_count'] ?? 0) is int ? j['pending_count'] : 0,
      presentDays: (m['present'] as num?)?.toInt() ?? 0,
      absentDays: (m['absent'] as num?)?.toInt() ?? 0,
      lateDays: (m['late'] as num?)?.toInt() ?? 0,
      todayShift: j['today_shift'] is Map
          ? TodayShift.fromJson(Map<String, dynamic>.from(j['today_shift']))
          : null,
      birthdays: birthdays,
      // Older builds of the API send the list without a total; falling back to
      // the slice length keeps the headline right instead of showing zero.
      birthdaysTotal:
          (j['birthdays_total'] as num?)?.toInt() ?? birthdays.length,
    );
  }
}

/// A colleague whose birthday is today, for the home screen's greeting card.
class BirthdayPerson {
  final int id;
  final String name;
  final String role;
  final String? photoUrl;
  final String initials;
  final Color avatarColor;

  /// True when the celebrant is the signed-in employee, so the card can say
  /// "kamu" instead of addressing them in the third person.
  final bool isMe;

  const BirthdayPerson({
    required this.id,
    required this.name,
    required this.role,
    required this.initials,
    required this.avatarColor,
    this.photoUrl,
    this.isMe = false,
  });

  factory BirthdayPerson.fromJson(Map<String, dynamic> j) => BirthdayPerson(
    id: (j['id'] as num?)?.toInt() ?? 0,
    name: (j['name'] ?? '').toString(),
    role: (j['role'] ?? '').toString(),
    photoUrl: j['photo_url']?.toString(),
    initials: (j['initials'] ?? '?').toString(),
    avatarColor: _hex(j['avatar_color']),
    isMe: j['is_me'] == true,
  );
}

/// Parses an `#rrggbb` string from the API, falling back to the brand blue.
Color _hex(dynamic value) {
  final s = (value ?? '#2547F9').toString().replaceAll('#', '');
  final v = int.tryParse(s.length == 6 ? 'FF$s' : s, radix: 16) ?? 0xFF2547F9;
  return Color(v);
}

/// Today's shift for the home card: a scheduled shift or an explicit day off.
class TodayShift {
  final bool isOff;
  final String? shiftName;
  final String? start;
  final String? end;

  const TodayShift({required this.isOff, this.shiftName, this.start, this.end});

  factory TodayShift.fromJson(Map<String, dynamic> j) => TodayShift(
    isOff: j['is_off'] == true,
    shiftName: j['shift_name']?.toString(),
    start: j['start']?.toString(),
    end: j['end']?.toString(),
  );
}
