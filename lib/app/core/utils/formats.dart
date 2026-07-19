import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

String formatRupiah(num value) => _rupiah.format(value);

const _months = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String monthLabel(int? month, int? year) {
  if (month == null || year == null) return '-';
  final m = (month >= 1 && month <= 12) ? _months[month] : '$month';
  return '$m $year';
}

/// The whole app reads timestamps as Waktu Indonesia Barat. Indonesia has no
/// DST, so a fixed +07:00 offset is exact — and it keeps labels stable even on
/// a device whose clock is set to another zone.
const _wibOffset = Duration(hours: 7);

/// Parse anything the API might hand us (ISO timestamp, bare date, DateTime)
/// into a WIB wall-clock DateTime. Returns null when there is nothing to parse.
DateTime? _toWib(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc().add(_wibOffset);
  final s = value.toString().trim();
  if (s.isEmpty) return null;
  final parsed = DateTime.tryParse(s);
  if (parsed == null) return null;
  // A bare "2026-07-15" carries no zone; it is already the intended day.
  if (!s.contains('T') && !s.contains(' ')) return parsed;
  return parsed.toUtc().add(_wibOffset);
}

/// "15 Jul 2026". Falls back to the raw value when it cannot be parsed.
String formatTanggal(dynamic value, {String fallback = '-'}) {
  final d = _toWib(value);
  if (d == null) {
    final s = value?.toString() ?? '';
    return s.isEmpty ? fallback : s;
  }
  return formatTanggalLokal(d);
}

/// "15 Jul 2026, 11.55 WIB" — for anything where the time of day matters.
String formatTanggalJam(dynamic value, {String fallback = '-'}) {
  final d = _toWib(value);
  if (d == null) {
    final s = value?.toString() ?? '';
    return s.isEmpty ? fallback : s;
  }
  final jam = d.hour.toString().padLeft(2, '0');
  final menit = d.minute.toString().padLeft(2, '0');
  return '${formatTanggalLokal(d)}, $jam.$menit WIB';
}

/// "11.55 WIB".
String formatJam(dynamic value, {String fallback = '-'}) {
  final d = _toWib(value);
  if (d == null) return fallback;
  return '${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')} WIB';
}

/// Format a DateTime that is already the wall-clock we want to show (a picked
/// date, say) without shifting it into another zone.
String formatTanggalLokal(DateTime d) => '${d.day} ${_months[d.month]} ${d.year}';
