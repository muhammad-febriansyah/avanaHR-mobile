/// One day in the employee's weekly schedule from `/me/schedule`. A day resolves
/// to a shift, an explicit day off, or "not yet scheduled" when no row exists.
class ShiftDay {
  final String date;
  final String dayLabel;
  final String dayShort;
  final bool isToday;
  final bool isScheduled;
  final bool isOff;
  final String? shiftName;
  final String? start;
  final String? end;

  const ShiftDay({
    required this.date,
    required this.dayLabel,
    required this.dayShort,
    required this.isToday,
    required this.isScheduled,
    required this.isOff,
    this.shiftName,
    this.start,
    this.end,
  });

  factory ShiftDay.fromJson(Map<String, dynamic> j) => ShiftDay(
        date: (j['date'] ?? '').toString(),
        dayLabel: (j['day_label'] ?? '').toString(),
        dayShort: (j['day_short'] ?? '').toString(),
        isToday: j['is_today'] == true,
        isScheduled: j['is_scheduled'] == true,
        isOff: j['is_off'] == true,
        shiftName: j['shift_name']?.toString(),
        start: j['start']?.toString(),
        end: j['end']?.toString(),
      );
}
