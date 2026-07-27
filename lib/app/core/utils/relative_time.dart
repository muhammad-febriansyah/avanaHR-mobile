/// Turns a timestamp into how long ago it was, in Indonesian.
///
/// A wall reads as a stream, so "2 jam lalu" tells the reader what they want to
/// know — how fresh this is — while "2026-07-27 09:14" makes them do the
/// arithmetic themselves.
class RelativeTime {
  /// Accepts the `YYYY-MM-DD HH:MM:SS` the API returns. Anything unparseable
  /// comes back as an empty string rather than throwing at render time.
  static String format(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) {
      return '';
    }

    final parsed = DateTime.tryParse(timestamp);

    if (parsed == null) {
      return '';
    }

    final diff = DateTime.now().difference(parsed);

    // A clock skew between phone and server can put a fresh post slightly in
    // the future; "baru saja" is truer than "-3 detik lalu".
    if (diff.isNegative || diff.inSeconds < 60) {
      return 'baru saja';
    }

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} menit lalu';
    }

    if (diff.inHours < 24) {
      return '${diff.inHours} jam lalu';
    }

    if (diff.inDays == 1) {
      return 'kemarin';
    }

    if (diff.inDays < 7) {
      return '${diff.inDays} hari lalu';
    }

    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return weeks == 1 ? 'seminggu lalu' : '$weeks minggu lalu';
    }

    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return months == 1 ? 'sebulan lalu' : '$months bulan lalu';
    }

    final years = (diff.inDays / 365).floor();

    return years == 1 ? 'setahun lalu' : '$years tahun lalu';
  }
}
