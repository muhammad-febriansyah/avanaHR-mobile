import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/widgets/app_toast.dart';
import '../../data/models/ess_models.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

/// "SOP Perusahaan" — the procedures this employee is allowed to read.
///
/// The server decides visibility, so everything returned here is safe to show;
/// the search and category filter below are presentation only.
class SopController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final items = <SopItem>[].obs;
  final search = ''.obs;
  final category = ''.obs;
  final busyId = Rxn<int>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// Distinct categories across the loaded SOPs, for the filter chips.
  List<String> get categories {
    final names = items.map((e) => e.category).toSet().toList()..sort();
    return names;
  }

  /// The SOPs matching the current search text and category filter.
  List<SopItem> get visible {
    final keyword = search.value.trim().toLowerCase();

    return items.where((sop) {
      if (category.value.isNotEmpty && sop.category != category.value) {
        return false;
      }

      if (keyword.isEmpty) {
        return true;
      }

      return [sop.title, sop.code ?? '', sop.summary ?? '']
          .any((field) => field.toLowerCase().contains(keyword));
    }).toList();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      items.assignAll(await _api.sops());
    } catch (_) {
      items.clear();
    }
    isLoading.value = false;
  }

  /// Download the SOP to a temp file and hand it to a device PDF viewer.
  Future<void> openPdf(SopItem sop) async {
    if (busyId.value != null) {
      return;
    }

    busyId.value = sop.id;
    try {
      final bytes = await _api.sopPdf(sop.id);
      if (bytes.isEmpty) {
        AppToast.error('Berkas SOP kosong.');
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sop-${sop.id}.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(file.path);
    } on DioException catch (e) {
      AppToast.error(ApiClient.messageFrom(e.response, 'Gagal mengunduh SOP.'));
    } catch (_) {
      AppToast.error('Gagal membuka SOP.');
    } finally {
      busyId.value = null;
    }
  }
}
