import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/widgets/app_toast.dart';
import '../../data/services/auth_service.dart';
import '../../routes/app_pages.dart';

class TwoFactorController extends GetxController {
  final AuthService _auth = Get.find();

  /// The single-use token the login handed over. It expires in five minutes,
  /// so a user who sits on this screen is sent back to sign in again.
  late final String challengeToken;

  final codeC = TextEditingController();

  final isLoading = false.obs;
  final useRecoveryCode = false.obs;

  @override
  void onInit() {
    super.onInit();
    challengeToken = (Get.arguments as String?) ?? '';
  }

  /// Swap between the six digits from the authenticator app and a recovery
  /// code, clearing whatever was typed for the other one.
  void toggleMode() {
    useRecoveryCode.toggle();
    codeC.clear();
  }

  Future<void> submit() async {
    final value = codeC.text.trim();

    if (value.isEmpty) {
      AppToast.warning(
        useRecoveryCode.value
            ? 'Masukkan kode pemulihan.'
            : 'Masukkan 6 digit kode dari aplikasi autentikator.',
      );
      return;
    }

    if (challengeToken.isEmpty) {
      _restartLogin();
      return;
    }

    isLoading.value = true;
    final result = await _auth.verifyTwoFactor(
      challengeToken,
      code: useRecoveryCode.value ? null : value,
      recoveryCode: useRecoveryCode.value ? value : null,
    );
    isLoading.value = false;

    if (result.isSuccess) {
      Get.offAllNamed(Routes.MAIN);
      return;
    }

    // A dead challenge cannot be retried from here — only a fresh password can
    // mint another one, so send them back rather than leave them typing codes
    // at a token the server has already thrown away.
    if (result.challengeExpired) {
      _restartLogin(result.error);
      return;
    }

    codeC.clear();
    AppToast.error(result.error!);
  }

  void _restartLogin([String? message]) {
    Get.offAllNamed(Routes.LOGIN);
    AppToast.error(message ?? 'Sesi verifikasi telah berakhir. Silakan masuk kembali.');
  }

  @override
  void onClose() {
    codeC.dispose();
    super.onClose();
  }
}
