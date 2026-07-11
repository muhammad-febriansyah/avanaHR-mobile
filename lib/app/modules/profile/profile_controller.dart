import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../core/widgets/app_toast.dart';
import '../../data/models/profile.dart';
import '../../data/providers/avana_api.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/storage_service.dart';
import '../../routes/app_pages.dart';

class ProfileController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final isSaving = false.obs;
  final profile = Rxn<Profile>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      profile.value = await _api.profile();
    } catch (_) {
      profile.value = null;
    }
    isLoading.value = false;
  }

  /// Save the self-editable contact fields. Returns true on success.
  Future<bool> updateProfile({
    required String phone,
    required String address,
  }) async {
    isSaving.value = true;
    try {
      profile.value = await _api.updateProfile(phone: phone, address: address);
      AppToast.success('Profil berhasil diperbarui');
      return true;
    } on DioException catch (e) {
      AppToast.error(_errorOf(e, 'Gagal memperbarui profil'));
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Change the password and persist the fresh token. Returns true on success.
  Future<bool> changePassword({
    required String current,
    required String password,
    required String confirm,
  }) async {
    isSaving.value = true;
    try {
      final token = await _api.changePassword(
        currentPassword: current,
        password: password,
        passwordConfirmation: confirm,
      );
      if (token != null && token.isNotEmpty) {
        await Get.find<StorageService>().saveToken(token);
      }
      AppToast.success('Kata sandi berhasil diperbarui');
      return true;
    } on DioException catch (e) {
      AppToast.error(_errorOf(e, 'Gagal mengubah kata sandi'));
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> logout() async {
    await Get.find<AuthService>().logout();
    Get.offAllNamed(Routes.LOGIN);
  }

  /// Extract a human message from a Laravel error response (422 validation or
  /// a plain message), falling back to [fallback].
  String _errorOf(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) {
          return first.first.toString();
        }
      }
      if (data['message'] is String && (data['message'] as String).isNotEmpty) {
        return data['message'] as String;
      }
    }
    return fallback;
  }
}
