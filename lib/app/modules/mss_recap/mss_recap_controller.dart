import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/widgets/app_toast.dart';
import '../../data/models/mss.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

/// Team attendance recap for a manager: per-member tallies over a month plus a
/// team summary, with CSV export. Backed by `/mss/attendance/recap`.
class MssRecapController extends GetxController {
  final AvanaApi _api = AvanaApi();

  static const _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  final isLoading = true.obs;
  final isExporting = false.obs;
  final rows = <TeamRecapRow>[].obs;
  final Rxn<TeamRecapSummary> summary = Rxn<TeamRecapSummary>();

  /// First day of the month currently shown.
  final Rx<DateTime> month = DateTime(DateTime.now().year, DateTime.now().month).obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  String get rangeLabel => '${_monthNames[month.value.month - 1]} ${month.value.year}';

  /// The month cursor cannot advance past the current calendar month.
  bool get canGoNext {
    final now = DateTime.now();
    return month.value.isBefore(DateTime(now.year, now.month));
  }

  String get _start => _fmt(DateTime(month.value.year, month.value.month, 1));
  String get _end => _fmt(DateTime(month.value.year, month.value.month + 1, 0));

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> prevMonth() async {
    month.value = DateTime(month.value.year, month.value.month - 1);
    await load();
  }

  Future<void> nextMonth() async {
    if (!canGoNext) {
      return;
    }
    month.value = DateTime(month.value.year, month.value.month + 1);
    await load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final recap = await _api.mssTeamRecap(start: _start, end: _end);
      rows.assignAll(recap.rows);
      summary.value = recap.summary;
    } catch (_) {
      rows.clear();
      summary.value = null;
    }
    isLoading.value = false;
  }

  Future<void> export() async {
    if (isExporting.value) {
      return;
    }
    if (rows.isEmpty) {
      AppToast.warning('Tidak ada data untuk diekspor.');
      return;
    }
    isExporting.value = true;
    try {
      final bytes = await _api.mssTeamRecapExport(start: _start, end: _end);
      if (bytes.isEmpty) {
        AppToast.error('File ekspor kosong.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/rekap-absensi-tim-$_start-$_end.csv');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Rekap absensi tim $rangeLabel',
        ),
      );
    } on DioException catch (e) {
      AppToast.error(ApiClient.messageFrom(e.response, 'Gagal mengekspor rekap.'));
    } catch (_) {
      AppToast.error('Gagal memproses ekspor.');
    } finally {
      isExporting.value = false;
    }
  }
}
