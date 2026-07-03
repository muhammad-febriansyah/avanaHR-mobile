import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;

import '../models/activity.dart';
import '../models/app_config.dart';
import '../models/app_notification.dart';
import '../models/dashboard.dart';
import '../models/attendance.dart';
import '../models/ess_models.dart';
import '../models/leave_balance.dart';
import '../models/onboarding_slide.dart';
import '../models/payslip.dart';
import '../models/profile.dart';
import '../models/user.dart';
import 'api_client.dart';

/// All AvanaHR mobile API calls live here (dio under the hood).
/// Methods throw [DioException] on transport errors; callers handle messaging.
class AvanaApi {
  Dio get _dio => Get.find<ApiClient>().dio;

  // ---- Public ----
  Future<AppConfig> appConfig() async {
    final res = await _dio.get('/app-config');
    return AppConfig.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<List<OnboardingSlide>> onboardingSlides() async {
    final res = await _dio.get('/onboarding-slides');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => OnboardingSlide.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // ---- Auth ----
  Future<Response> login(
    String email,
    String password, {
    Map<String, dynamic>? device,
  }) =>
      _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
        ...?device,
      });

  Future<AppUser> me() async {
    final res = await _dio.get('/auth/me');
    return AppUser.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<void> logout() => _dio.post('/auth/logout');

  // ---- ESS read ----
  Future<Profile> profile() async {
    final res = await _dio.get('/me/profile');
    return Profile.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<AttendanceToday> attendanceToday() async {
    final res = await _dio.get('/me/attendance/today');
    return AttendanceToday.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<List<Payslip>> payslips() async {
    final res = await _dio.get('/me/payslips');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => Payslip.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Payslip> payslip(int id) async {
    final res = await _dio.get('/me/payslips/$id');
    return Payslip.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<List<LeaveBalance>> leaveBalances() async {
    final res = await _dio.get('/me/leave/balances');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => LeaveBalance.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<({List<AppNotification> items, int unread})> notifications() async {
    final res = await _dio.get('/me/notifications');
    final list = (res.data['data'] as List?) ?? [];
    final meta = res.data['meta'] is Map ? res.data['meta'] : {};
    return (
      items: list.map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e))).toList(),
      unread: (meta['unread'] ?? 0) as int,
    );
  }

  Future<void> readAllNotifications() => _dio.post('/me/notifications/read-all');

  // ---- ESS write ----
  Future<Response> clock({
    required String type,
    double? latitude,
    double? longitude,
    List<double>? faceEmbedding,
    String? deviceId,
    bool? isMockLocation,
    bool? isRooted,
    String? clockedAt,
  }) =>
      _dio.post('/me/attendance/clock', data: {
        'type': type,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (faceEmbedding != null) 'face_embedding': faceEmbedding,
        if (deviceId != null) 'device_id': deviceId,
        if (isMockLocation != null) 'is_mock_location': isMockLocation,
        if (isRooted != null) 'is_rooted': isRooted,
        if (clockedAt != null) 'clocked_at': clockedAt,
      });

  // ---- Home dashboard ----
  Future<DashboardSummary> dashboard() async {
    final res = await _dio.get('/me/dashboard');

    return DashboardSummary.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<List<WorkLocationItem>> workLocations() async {
    final res = await _dio.get('/me/work-locations');
    final list = (res.data['data'] as List?) ?? [];

    return list.map((e) => WorkLocationItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // ---- Activity feed (Riwayat) ----
  Future<List<ActivityItem>> activities() async {
    final res = await _dio.get('/me/activities');
    final list = (res.data['data'] as List?) ?? [];

    return list.map((e) => ActivityItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // ---- Face recognition ----
  Future<Response> faceStatus() => _dio.get('/me/face');

  Future<Response> enrollFace(List<double> embedding) =>
      _dio.post('/me/face/enroll', data: {'embedding': embedding});

  Future<Response> submitLeave({
    required int leaveTypeId,
    required String startDate,
    required String endDate,
    String? reason,
  }) =>
      _dio.post('/me/leave-requests', data: {
        'leave_type_id': leaveTypeId,
        'start_date': startDate,
        'end_date': endDate,
        if (reason != null) 'reason': reason,
      });

  Future<Response> submitReimbursement({required String category, required int amount}) =>
      _dio.post('/me/reimbursements', data: {'category': category, 'amount': amount});

  Future<List<ReimbursementItem>> reimbursements() async {
    final res = await _dio.get('/me/reimbursements');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => ReimbursementItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // ---- Leave ----
  Future<List<LeaveType>> leaveTypes() async {
    final res = await _dio.get('/me/leave-types');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => LeaveType.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<LeaveRequestItem>> leaveRequests() async {
    final res = await _dio.get('/me/leave-requests');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => LeaveRequestItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // ---- Overtime ----
  Future<List<OvertimeItem>> overtimes() async {
    final res = await _dio.get('/me/overtime');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => OvertimeItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Response> submitOvertime({required String date, required double hours, String? reason}) =>
      _dio.post('/me/overtime', data: {'date': date, 'hours': hours, if (reason != null) 'reason': reason});

  // ---- Permission (izin) ----
  Future<List<PermissionItem>> permissions() async {
    final res = await _dio.get('/me/permissions');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => PermissionItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Response> submitPermission({required String date, required String type, String? startTime, String? endTime, String? reason}) =>
      _dio.post('/me/permissions', data: {
        'date': date,
        'type': type,
        if (startTime != null) 'start_time': startTime,
        if (endTime != null) 'end_time': endTime,
        if (reason != null) 'reason': reason,
      });

  // ---- WFH ----
  Future<List<WfhItem>> wfhs() async {
    final res = await _dio.get('/me/wfh');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => WfhItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Response> submitWfh({required String startDate, required String endDate, String? reason}) =>
      _dio.post('/me/wfh', data: {'start_date': startDate, 'end_date': endDate, if (reason != null) 'reason': reason});

  // ---- Announcements ----
  Future<List<AnnouncementItem>> announcements() async {
    final res = await _dio.get('/me/announcements');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => AnnouncementItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // ---- MSS ----
  Future<List<dynamic>> approvals() async {
    final res = await _dio.get('/mss/approvals');
    return (res.data['data'] as List?) ?? [];
  }

  Future<Response> actApproval(int id, String action, {String? reason}) =>
      _dio.post('/mss/approvals/$id/act', data: {'action': action, if (reason != null) 'reason': reason});

  Future<Response> bulkApproval(List<int> ids, String action, {String? reason}) =>
      _dio.post('/mss/approvals/bulk', data: {'ids': ids, 'action': action, if (reason != null) 'reason': reason});

  Future<List<dynamic>> team() async {
    final res = await _dio.get('/mss/team');
    return (res.data['data'] as List?) ?? [];
  }

  // ---- Documents ----
  Future<List<DocumentItem>> documents() async {
    final res = await _dio.get('/me/documents');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => DocumentItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Response> submitDocument({required String name, String? type, required String filePath}) async {
    final form = FormData.fromMap({
      'name': name,
      if (type != null && type.isNotEmpty) 'type': type,
      'file': await MultipartFile.fromFile(filePath, filename: filePath.split('/').last),
    });
    return _dio.post('/me/documents', data: form);
  }

  // ---- Field visits ----
  Future<List<FieldVisitItem>> fieldVisits() async {
    final res = await _dio.get('/me/field-visits');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => FieldVisitItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Response> submitFieldVisit({
    required String visitDate,
    required String location,
    String? clientName,
    String? purpose,
    String? notes,
    double? latitude,
    double? longitude,
    String? photoPath,
  }) async {
    final form = FormData.fromMap({
      'visit_date': visitDate,
      'location': location,
      if (clientName != null && clientName.isNotEmpty) 'client_name': clientName,
      if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (photoPath != null) 'photo': await MultipartFile.fromFile(photoPath, filename: photoPath.split('/').last),
    });
    return _dio.post('/me/field-visits', data: form);
  }

  // ---- Shift swaps ----
  Future<List<ShiftSwapItem>> shiftSwaps() async {
    final res = await _dio.get('/me/shift-swaps');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => ShiftSwapItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<Colleague>> swapColleagues() async {
    final res = await _dio.get('/me/shift-swaps/colleagues');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => Colleague.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Response> submitShiftSwap({required int targetId, required String date, String? reason}) =>
      _dio.post('/me/shift-swaps', data: {
        'target_id': targetId,
        'date': date,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
}
