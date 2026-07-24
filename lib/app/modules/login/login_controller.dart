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
    final error = await _auth.login(emailC.text.trim(), passwordC.text);
    isLoading.value = false;

    if (error == null) {
      if (rememberMe.value) {
        await _storage.saveRememberedEmail(emailC.text.trim());
      } else {
        await _storage.clearRememberedEmail();
      }
      // Show the tenant-branded welcome splash, which forwards to MAIN.
      Get.offAllNamed(Routes.BRAND_SPLASH);
    } else {
      AppToast.error(error);
    }
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
