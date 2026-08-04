import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/widgets/app_toast.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/storage_service.dart';
import '../../routes/app_pages.dart';

class LoginController extends GetxController {
  final AuthService _auth = Get.find();
  final StorageService _storage = Get.find();

  final emailC = TextEditingController();
  final passwordC = TextEditingController();

  final isLoading = false.obs;
  final obscure = true.obs;
  final rememberMe = false.obs;

  @override
  void onInit() {
    super.onInit();
    final saved = _storage.rememberedEmail;
    if (saved != null && saved.isNotEmpty) {
      emailC.text = saved;
      rememberMe.value = true;
    }
  }

  Future<void> submit() async {
    if (emailC.text.trim().isEmpty || passwordC.text.isEmpty) {
      AppToast.warning('Email dan kata sandi wajib diisi.');
      return;
    }

    isLoading.value = true;
    final result = await _auth.login(emailC.text.trim(), passwordC.text);
    isLoading.value = false;

    if (result.error != null) {
      AppToast.error(result.error!);
      return;
    }

    // The address is worth remembering either way: the account is real and the
    // password was right, whatever the second factor decides next.
    if (rememberMe.value) {
      await _storage.saveRememberedEmail(emailC.text.trim());
    } else {
      await _storage.clearRememberedEmail();
    }

    if (result.needsTwoFactor) {
      // Not offAllNamed: backing out of the code screen should land on login,
      // not on an empty stack.
      Get.toNamed(Routes.TWO_FACTOR, arguments: result.challengeToken);
      return;
    }

    Get.offAllNamed(Routes.MAIN);
  }

  void forgotPassword() {
    AppToast.info('Hubungi admin HR perusahaan Anda untuk mengatur ulang kata sandi.');
  }

  @override
  void onClose() {
    emailC.dispose();
    passwordC.dispose();
    super.onClose();
  }
}
