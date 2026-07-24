import 'package:get/get.dart';

import '../modules/ai_assistant/ai_assistant_binding.dart';
import '../modules/ai_assistant/ai_assistant_view.dart';
import '../modules/announcement/announcement_binding.dart';
import '../modules/announcement/announcement_view.dart';
import '../modules/dokumen/dokumen_binding.dart';
import '../modules/dokumen/dokumen_view.dart';
import '../modules/face_enroll/face_enroll_binding.dart';
import '../modules/face_enroll/face_enroll_view.dart';
import '../modules/face_verify/face_verify_binding.dart';
import '../modules/face_verify/face_verify_view.dart';
import '../modules/shift_swap/shift_swap_binding.dart';
import '../modules/shift_swap/shift_swap_view.dart';
import '../modules/visiting/visiting_binding.dart';
import '../modules/visiting/visiting_report_view.dart';
import '../modules/visiting/visiting_view.dart';
import '../modules/attendance/attendance_binding.dart';
import '../modules/attendance/attendance_view.dart';
import '../modules/attendance_correction/attendance_correction_binding.dart';
import '../modules/attendance_correction/attendance_correction_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/leave/leave_binding.dart';
import '../modules/leave/leave_view.dart';
import '../modules/mss/mss_binding.dart';
import '../modules/mss/mss_view.dart';
import '../modules/mss_member/mss_member_binding.dart';
import '../modules/mss_member/mss_member_view.dart';
import '../modules/mss_recap/mss_recap_binding.dart';
import '../modules/mss_recap/mss_recap_view.dart';
import '../modules/dashboard/dashboard_binding.dart';
import '../modules/dashboard/dashboard_view.dart';
import '../modules/overtime/overtime_binding.dart';
import '../modules/overtime/overtime_view.dart';
import '../modules/permission/permission_binding.dart';
import '../modules/permission/permission_view.dart';
import '../modules/schedule/schedule_binding.dart';
import '../modules/schedule/schedule_view.dart';
import '../modules/reimbursement/reimbursement_binding.dart';
import '../modules/kasbon/kasbon_binding.dart';
import '../modules/kasbon/kasbon_detail_view.dart';
import '../modules/kasbon/kasbon_view.dart';
import '../modules/settlement/settlement_binding.dart';
import '../modules/settlement/settlement_detail_view.dart';
import '../modules/settlement/settlement_view.dart';
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
import '../modules/brand_splash/brand_splash_view.dart';
import '../modules/profile/profile_binding.dart';
import '../modules/profile/profile_view.dart';
import '../modules/splash/splash_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.SPLASH;

  static final routes = [
    GetPage(name: _Paths.SPLASH, page: () => const SplashView()),
    GetPage(name: _Paths.BRAND_SPLASH, page: () => const BrandSplashView()),
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
      name: _Paths.KASBON,
      page: () => const KasbonView(),
      binding: KasbonBinding(),
    ),
    GetPage(
      name: _Paths.KASBON_DETAIL,
      page: () => const KasbonDetailView(),
      binding: KasbonBinding(),
    ),
    GetPage(
      name: _Paths.SETTLEMENT,
      page: () => const SettlementView(),
      binding: SettlementBinding(),
    ),
    GetPage(
      name: _Paths.SETTLEMENT_DETAIL,
      page: () => const SettlementDetailView(),
      binding: SettlementBinding(),
    ),
    GetPage(
      name: _Paths.ANNOUNCEMENT,
      page: () => const AnnouncementView(),
      binding: AnnouncementBinding(),
    ),
    GetPage(
      name: _Paths.DOKUMEN,
      page: () => const DokumenView(),
      binding: DokumenBinding(),
    ),
    GetPage(
      name: _Paths.VISITING,
      page: () => const VisitingView(),
      binding: VisitingBinding(),
    ),
    GetPage(
      name: _Paths.VISITING_REPORT,
      page: () => const VisitingReportView(),
      binding: VisitingBinding(),
    ),
    GetPage(
      name: _Paths.SHIFT_SWAP,
      page: () => const ShiftSwapView(),
      binding: ShiftSwapBinding(),
    ),
    GetPage(
      name: _Paths.FACE_ENROLL,
      page: () => const FaceEnrollView(),
      binding: FaceEnrollBinding(),
    ),
    GetPage(
      name: _Paths.FACE_VERIFY,
      page: () => const FaceVerifyView(),
      binding: FaceVerifyBinding(),
    ),
    GetPage(
      name: _Paths.MSS,
      page: () => const MssView(),
      binding: MssBinding(),
    ),
    GetPage(
      name: _Paths.ATTENDANCE_CORRECTION,
      page: () => const AttendanceCorrectionView(),
      binding: AttendanceCorrectionBinding(),
    ),
    GetPage(
      name: _Paths.SCHEDULE,
      page: () => const ScheduleView(),
      binding: ScheduleBinding(),
    ),
    GetPage(
      name: _Paths.MSS_MEMBER,
      page: () => const MssMemberView(),
      binding: MssMemberBinding(),
    ),
    GetPage(
      name: _Paths.MSS_RECAP,
      page: () => const MssRecapView(),
      binding: MssRecapBinding(),
    ),
    GetPage(
      name: _Paths.DASHBOARD,
      page: () => const DashboardView(),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: _Paths.AI_ASSISTANT,
      page: () => const AiAssistantView(),
      binding: AiAssistantBinding(),
    ),
  ];
}
