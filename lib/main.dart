import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:toastification/toastification.dart';

import 'app/core/theme/app_theme.dart';
import 'app/data/providers/api_client.dart';
import 'app/data/services/auth_service.dart';
import 'app/data/services/config_service.dart';
import 'app/data/services/connectivity_service.dart';
import 'app/data/services/device_service.dart';
import 'app/data/services/storage_service.dart';
import 'app/routes/app_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await GetStorage.init();

  // Permanent services, ordered by dependency.
  await Get.putAsync(() async => StorageService());
  Get.put(ApiClient(), permanent: true);
  Get.put(ConnectivityService(), permanent: true);
  Get.put(DeviceService(), permanent: true);
  Get.put(AuthService(), permanent: true);
  Get.put(ConfigService(), permanent: true);
  // Warm branding in the background so any entry point (deep link too) has it.
  Get.find<ConfigService>().load();

  runApp(const AvanaApp());
}

class AvanaApp extends StatelessWidget {
  const AvanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) => ToastificationWrapper(
        child: GetMaterialApp(
          title: 'AvanaHR',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          initialRoute: AppPages.INITIAL,
          getPages: AppPages.routes,
        ),
      ),
    );
  }
}
