import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/widgets/app_toast.dart';
import '../../data/models/payslip.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

class PayslipController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final items = <Payslip>[].obs;

  /// Id of the payslip whose PDF is currently downloading (null = idle).
  final busyId = RxnInt();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      items.assignAll(await _api.payslips());
    } catch (_) {
      items.clear();
    }
    isLoading.value = false;
  }

  /// Download the payslip PDF to a temp file and open it in a device viewer.
  Future<void> openPdf(int id) => _withPdf(id, (path) => OpenFilex.open(path));

  /// Download the payslip PDF to a temp file and hand it to the share sheet.
  Future<void> sharePdf(int id) => _withPdf(
        id,
        (path) => SharePlus.instance.share(
          ShareParams(files: [XFile(path)], text: 'Slip gaji'),
        ),
      );

  Future<void> _withPdf(int id, Future<void> Function(String path) action) async {
    if (busyId.value != null) {
      return;
    }
    busyId.value = id;
    try {
      final bytes = await _api.payslipPdf(id);
      if (bytes.isEmpty) {
        AppToast.error('Slip kosong.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/slip-$id.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await action(file.path);
    } on DioException catch (e) {
      AppToast.error(ApiClient.messageFrom(e.response, 'Gagal mengunduh slip.'));
    } catch (_) {
      AppToast.error('Gagal memproses slip.');
    } finally {
      busyId.value = null;
    }
  }
}
