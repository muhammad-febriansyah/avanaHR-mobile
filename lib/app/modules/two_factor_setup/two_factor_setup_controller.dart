import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/widgets/app_toast.dart';
import '../../data/models/two_factor_status.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

/// Turning the second factor on and off from the phone.
///
/// Every call answers with the whole status, so the screen never has to guess
/// which of the three states it is in — it just renders what came back.
class TwoFactorSetupController extends GetxController {
  final _api = AvanaApi();

  final status = const TwoFactorStatus.off().obs;

  final isLoading = true.obs;
  final isWorking = false.obs;

  /// Set when the first load failed. An account with two-factor off and one
  /// whose status could not be read look identical otherwise, and offering to
  /// turn on a factor that may already be on is the wrong thing to show.
  final loadError = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      status.value = await _api.twoFactorStatus();
      loadError.value = null;
    } on DioException catch (e) {
      loadError.value = ApiClient.errorMessage(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> enable(String currentPassword) =>
      _run(() => _api.enableTwoFactor(currentPassword), 'Gagal memulai aktivasi');

  Future<bool> confirm(String code) => _run(
    () => _api.confirmTwoFactor(code),
    'Kode tidak valid',
    onDone: () => AppToast.success('Verifikasi dua langkah aktif'),
  );

  Future<bool> disable(String currentPassword) => _run(
    () => _api.disableTwoFactor(currentPassword),
    'Gagal menonaktifkan',
    onDone: () => AppToast.info('Verifikasi dua langkah dimatikan'),
  );

  Future<bool> regenerateRecoveryCodes(String currentPassword) => _run(
    () => _api.regenerateRecoveryCodes(currentPassword),
    'Gagal membuat ulang kode pemulihan',
    onDone: () => AppToast.success('Kode pemulihan baru dibuat'),
  );

  /// Cancel a half-finished enrolment. The secret is thrown away, which is what
  /// disabling does — the account was never protected by it in the first place.
  Future<bool> cancelSetup(String currentPassword) =>
      _run(() => _api.disableTwoFactor(currentPassword), 'Gagal membatalkan');

  void copyRecoveryCodes() {
    final codes = status.value.recoveryCodes;
    if (codes.isEmpty) {
      return;
    }

    Clipboard.setData(ClipboardData(text: codes.join('\n')));
    AppToast.success('Kode pemulihan disalin');
  }

  void copySetupKey() {
    final key = status.value.setupKey;
    if (key == null || key.isEmpty) {
      return;
    }

    Clipboard.setData(ClipboardData(text: key));
    AppToast.success('Kunci disalin');
  }

  /// Run a call that returns the new status, keeping one failure path.
  Future<bool> _run(
    Future<TwoFactorStatus> Function() call,
    String fallback, {
    void Function()? onDone,
  }) async {
    isWorking.value = true;
    try {
      status.value = await call();
      onDone?.call();
      return true;
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
      return false;
    } catch (_) {
      AppToast.error(fallback);
      return false;
    } finally {
      isWorking.value = false;
    }
  }
}
