import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart' hide Response;

import '../../core/widgets/app_toast.dart';
import '../../data/models/ess_models.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

class VisitingController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final submitting = false.obs;
  final items = <FieldVisitItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      items.assignAll(await _api.fieldVisits());
    } catch (_) {}
    isLoading.value = false;
  }

  /// Best-effort current GPS; null if permission denied or service off.
  Future<Position?> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  Future<bool> submit({
    required String visitDate,
    required String location,
    String? clientName,
    String? purpose,
    String? notes,
    double? latitude,
    double? longitude,
    String? photoPath,
  }) async {
    submitting.value = true;
    try {
      final res = await _api.submitFieldVisit(
        visitDate: visitDate,
        location: location,
        clientName: clientName,
        purpose: purpose,
        notes: notes,
        latitude: latitude,
        longitude: longitude,
        photoPath: photoPath,
      );
      submitting.value = false;
      if (res.statusCode == 201) {
        AppToast.success('Kunjungan tercatat');
        await load();
        return true;
      }
      AppToast.error(ApiClient.messageFrom(res, 'Gagal menyimpan kunjungan.'));
      return false;
    } on DioException catch (e) {
      submitting.value = false;
      AppToast.error(ApiClient.errorMessage(e));
      return false;
    }
  }
}
