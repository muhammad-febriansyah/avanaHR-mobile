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
