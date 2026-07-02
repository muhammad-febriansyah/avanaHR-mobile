import 'package:get/get.dart';

import '../modules/announcement/announcement_binding.dart';
import '../modules/announcement/announcement_view.dart';
import '../modules/attendance/attendance_binding.dart';
import '../modules/attendance/attendance_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/leave/leave_binding.dart';
import '../modules/leave/leave_view.dart';
import '../modules/overtime/overtime_binding.dart';
import '../modules/overtime/overtime_view.dart';
import '../modules/permission/permission_binding.dart';
import '../modules/permission/permission_view.dart';
import '../modules/reimbursement/reimbursement_binding.dart';
import '../modules/reimbursement/reimbursement_view.dart';
import '../modules/wfh/wfh_binding.dart';
import '../modules/wfh/wfh_view.dart';
import '../modules/home/views/home_view.dart';
import '../modules/login/login_binding.dart';
import '../modules/login/login_view.dart';
import '../modules/main/main_binding.dart';
import '../modules/main/main_view.dart';
import '../modules/notification/notification_binding.dart';
import '../modules/notification/notification_view.dart';
import '../modules/onboarding/onboarding_view.dart';
import '../modules/payslip/payslip_binding.dart';
import '../modules/payslip/payslip_view.dart';
import '../modules/profile/profile_binding.dart';
import '../modules/profile/profile_view.dart';
import '../modules/splash/splash_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.SPLASH;

  static final routes = [
    GetPage(name: _Paths.SPLASH, page: () => const SplashView()),
    GetPage(name: _Paths.ONBOARDING, page: () => const OnboardingView()),
    GetPage(
      name: _Paths.LOGIN,
      page: () => const LoginView(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: _Paths.MAIN,
      page: () => const MainView(),
      binding: MainBinding(),
    ),
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.PROFILE,
      page: () => const ProfileView(),
      binding: ProfileBinding(),
    ),
    GetPage(
      name: _Paths.ATTENDANCE,
      page: () => const AttendanceView(),
      binding: AttendanceBinding(),
    ),
    GetPage(
      name: _Paths.PAYSLIP,
      page: () => const PayslipView(),
      binding: PayslipBinding(),
    ),
    GetPage(
      name: _Paths.NOTIFICATION,
      page: () => const NotificationView(),
      binding: NotificationBinding(),
    ),
    GetPage(
      name: _Paths.LEAVE,
      page: () => const LeaveView(),
      binding: LeaveBinding(),
    ),
    GetPage(
      name: _Paths.OVERTIME,
      page: () => const OvertimeView(),
      binding: OvertimeBinding(),
    ),
    GetPage(
      name: _Paths.PERMISSION,
      page: () => const PermissionView(),
      binding: PermissionBinding(),
    ),
    GetPage(
      name: _Paths.WFH,
      page: () => const WfhView(),
      binding: WfhBinding(),
    ),
    GetPage(
      name: _Paths.REIMBURSEMENT,
      page: () => const ReimbursementView(),
      binding: ReimbursementBinding(),
    ),
    GetPage(
      name: _Paths.ANNOUNCEMENT,
      page: () => const AnnouncementView(),
      binding: AnnouncementBinding(),
    ),
  ];
}
