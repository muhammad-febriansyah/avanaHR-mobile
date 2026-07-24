import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;

import '../models/activity.dart';
import '../models/ai_models.dart';
import '../models/app_config.dart';
import '../models/app_notification.dart';
import '../models/dashboard.dart';
import '../models/attendance.dart';
import '../models/ess_models.dart';
import '../models/leave_balance.dart';
import '../models/mss.dart';
import '../models/onboarding_slide.dart';
import '../models/payslip.dart';
import '../models/profile.dart';
import '../models/schedule.dart';
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
    return list
        .map((e) => OnboardingSlide.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---- Auth ----
  Future<Response> login(
    String email,
    String password, {
    Map<String, dynamic>? device,
  }) => _dio.post(
    '/auth/login',
    data: {'email': email, 'password': password, ...?device},
  );

  Future<AppUser> me() async {
    final res = await _dio.get('/auth/me');
    final data = res.data is Map ? (res.data as Map)['data'] : null;
    if (data is! Map) {
      // No/expired token or an unexpected shape (e.g. a 401 error body) yields
      // null here — surface it as a clean failure the caller can handle instead
      // of a raw TypeError from Map.from(null).
      throw StateError('Unexpected /auth/me response');
    }
    return AppUser.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> logout() => _dio.post('/auth/logout');

  // ---- ESS read ----
  Future<Profile> profile() async {
    final res = await _dio.get('/me/profile');
    return Profile.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// Update the caller's self-editable fields (phone, address).
  Future<Profile> updateProfile({String? phone, String? address}) async {
    final res = await _dio.put(
      '/me/profile',
      data: {'phone': phone, 'address': address},
    );
    return Profile.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// Change the account password. Old tokens are revoked server-side, so the
  /// returned fresh access token must replace the stored one.
  Future<String?> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    final res = await _dio.post(
      '/me/security/password',
      data: {
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
    return res.data['access_token'] as String?;
  }

  Future<AttendanceToday> attendanceToday() async {
    final res = await _dio.get('/me/attendance/today');
    final requirements = res.data['requirements'];

    return AttendanceToday.fromJson(
      Map<String, dynamic>.from(res.data['data']),
      requirements: requirements is Map
          ? Map<String, dynamic>.from(requirements)
          : const {},
    );
  }

  Future<List<Payslip>> payslips() async {
    final res = await _dio.get('/me/payslips');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => Payslip.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Payslip> payslip(int id) async {
    final res = await _dio.get('/me/payslips/$id');
    return Payslip.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// Raw PDF bytes for a payslip (password-protected server-side).
  Future<List<int>> payslipPdf(int id) async {
    final res = await _dio.get<List<int>>(
      '/me/payslips/$id/pdf',
      options: Options(responseType: ResponseType.bytes),
    );

    return res.data ?? <int>[];
  }

  Future<List<LeaveBalance>> leaveBalances() async {
    final res = await _dio.get('/me/leave/balances');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => LeaveBalance.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<({List<AppNotification> items, int unread})> notifications() async {
    final res = await _dio.get('/me/notifications');
    final list = (res.data['data'] as List?) ?? [];
    final meta = res.data['meta'] is Map ? res.data['meta'] : {};
    return (
      items: list
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      unread: (meta['unread'] ?? 0) as int,
    );
  }

  Future<void> readAllNotifications() =>
      _dio.post('/me/notifications/read-all');

  Future<void> readNotification(int id) =>
      _dio.post('/me/notifications/$id/read');

  // ---- ESS write ----
  Future<Response> clock({
    required String type,
    String? workMode,
    double? latitude,
    double? longitude,
    List<double>? faceEmbedding,
    String? deviceId,
    bool? isMockLocation,
    bool? isRooted,
    bool? isEmulator,
    String? clockedAt,
    String? selfiePath,
  }) async {
    final fields = <String, dynamic>{
      'type': type,
      if (workMode != null) 'work_mode': workMode,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (faceEmbedding != null) 'face_embedding': faceEmbedding,
      if (deviceId != null) 'device_id': deviceId,
      if (isMockLocation != null) 'is_mock_location': isMockLocation,
      if (isRooted != null) 'is_rooted': isRooted,
      if (isEmulator != null) 'is_emulator': isEmulator,
      if (clockedAt != null) 'clocked_at': clockedAt,
    };

    // No selfie → plain JSON. With a selfie → multipart so the captured face
    // frame is uploaded as the attendance photo (verification stays on-device).
    if (selfiePath == null) {
      return _dio.post('/me/attendance/clock', data: fields);
    }

    final selfie = await MultipartFile.fromFile(
      selfiePath,
      filename: 'selfie.jpg',
    );

    // Multipart quirks vs Laravel validation:
    //  - bools serialise to "true"/"false" strings the `boolean` rule rejects
    //    → send '1'/'0'.
    //  - a List repeats the bare key, which Laravel reads as a scalar (fails
    //    the `array` rule) → emit `face_embedding[]` entries instead.
    final form = FormData();
    fields.forEach((key, value) {
      if (value is List) {
        for (final element in value) {
          form.fields.add(MapEntry('$key[]', element.toString()));
        }
      } else if (value is bool) {
        form.fields.add(MapEntry(key, value ? '1' : '0'));
      } else {
        form.fields.add(MapEntry(key, value.toString()));
      }
    });
    form.files.add(MapEntry('selfie', selfie));

    return _dio.post('/me/attendance/clock', data: form);
  }

  // ---- Attendance corrections (koreksi absen) ----
  Future<List<AttendanceCorrectionItem>> attendanceCorrections() async {
    final res = await _dio.get('/me/attendance/corrections');
    final list = (res.data['data'] as List?) ?? [];

    return list
        .map(
          (e) =>
              AttendanceCorrectionItem.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<Response> submitCorrection({
    required String date,
    String? clockIn,
    String? clockOut,
    required String reason,
  }) => _dio.post(
    '/me/attendance/corrections',
    data: {
      'date': date,
      if (clockIn != null) 'requested_clock_in': clockIn,
      if (clockOut != null) 'requested_clock_out': clockOut,
      'reason': reason,
    },
  );

  // ---- Schedule (jadwal shift) ----
  Future<List<ShiftDay>> schedule({String? start}) async {
    final res = await _dio.get(
      '/me/schedule',
      queryParameters: {if (start != null) 'start': start},
    );
    final list = (res.data['data'] as List?) ?? [];

    return list
        .map((e) => ShiftDay.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---- Home dashboard ----
  Future<DashboardSummary> dashboard() async {
    final res = await _dio.get('/me/dashboard');

    return DashboardSummary.fromJson(
      Map<String, dynamic>.from(res.data['data']),
    );
  }

  Future<Response> moodToday() => _dio.get('/me/mood');

  Future<Response> submitMood(String mood) =>
      _dio.post('/me/mood', data: {'mood': mood});

  Future<List<WorkLocationItem>> workLocations() async {
    final res = await _dio.get('/me/work-locations');
    final list = (res.data['data'] as List?) ?? [];

    return list
        .map((e) => WorkLocationItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---- Activity feed (Riwayat) ----
  Future<List<ActivityItem>> activities() async {
    final res = await _dio.get('/me/activities');
    final list = (res.data['data'] as List?) ?? [];

    return list
        .map((e) => ActivityItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
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
  }) => _dio.post(
    '/me/leave-requests',
    data: {
      'leave_type_id': leaveTypeId,
      'start_date': startDate,
      'end_date': endDate,
      if (reason != null) 'reason': reason,
    },
  );

  Future<Response> submitReimbursement({
    required String category,
    required int amount,
    String? receiptPath,
  }) async {
    if (receiptPath == null) {
      return _dio.post(
        '/me/reimbursements',
        data: {'category': category, 'amount': amount},
      );
    }
    final form = FormData.fromMap({
      'category': category,
      'amount': amount,
      'receipt': await MultipartFile.fromFile(
        receiptPath,
        filename: receiptPath.split('/').last,
      ),
    });
    return _dio.post('/me/reimbursements', data: form);
  }

  Future<List<ReimbursementItem>> reimbursements() async {
    final res = await _dio.get('/me/reimbursements');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => ReimbursementItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---- Cash Advance (Uang Muka) ----
  Future<List<CashAdvanceItem>> cashAdvances() async {
    final res = await _dio.get('/me/cash-advances');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => CashAdvanceItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CashAdvanceDetail> cashAdvance(int id) async {
    final res = await _dio.get('/me/cash-advances/$id');

    return CashAdvanceDetail.fromJson(
      Map<String, dynamic>.from(res.data['data']),
    );
  }

  Future<Response> submitCashAdvance({
    required int amount,
    required String purpose,
    required String neededDate,
    String? reason,
  }) => _dio.post(
    '/me/cash-advances',
    data: {
      'amount': amount,
      'purpose': purpose,
      'needed_date': neededDate,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    },
  );

  // ---- Settlement (Perdin) ----
  Future<List<SettlementItem>> settlements() async {
    final res = await _dio.get('/me/settlements');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => SettlementItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<SettlementDetail> settlement(int id) async {
    final res = await _dio.get('/me/settlements/$id');

    return SettlementDetail.fromJson(
      Map<String, dynamic>.from(res.data['data']),
    );
  }

  // ---- Leave ----
  Future<List<LeaveType>> leaveTypes() async {
    final res = await _dio.get('/me/leave-types');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => LeaveType.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<LeaveRequestItem>> leaveRequests() async {
    final res = await _dio.get('/me/leave-requests');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => LeaveRequestItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---- Overtime ----
  Future<List<OvertimeItem>> overtimes() async {
    final res = await _dio.get('/me/overtime');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => OvertimeItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Response> submitOvertime({
    required String date,
    required double hours,
    String? reason,
  }) => _dio.post(
    '/me/overtime',
    data: {'date': date, 'hours': hours, if (reason != null) 'reason': reason},
  );

  // ---- Permission (izin) ----
  Future<List<PermissionItem>> permissions() async {
    final res = await _dio.get('/me/permissions');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => PermissionItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Response> submitPermission({
    required String startDate,
    required String endDate,
    required String type,
    String? startTime,
    String? endTime,
    String? reason,
  }) => _dio.post(
    '/me/permissions',
    data: {
      'start_date': startDate,
      'end_date': endDate,
      'type': type,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (reason != null) 'reason': reason,
    },
  );

  // ---- WFH ----
  Future<List<WfhItem>> wfhs() async {
    final res = await _dio.get('/me/wfh');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => WfhItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Response> submitWfh({
    required String startDate,
    required String endDate,
    String? reason,
  }) => _dio.post(
    '/me/wfh',
    data: {
      'start_date': startDate,
      'end_date': endDate,
      if (reason != null) 'reason': reason,
    },
  );

  // ---- Announcements ----
  Future<List<AnnouncementItem>> announcements() async {
    final res = await _dio.get('/me/announcements');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => AnnouncementItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---- MSS ----
  Future<List<dynamic>> approvals() async {
    final res = await _dio.get('/mss/approvals');
    return (res.data['data'] as List?) ?? [];
  }

  Future<List<dynamic>> mssHistory() async {
    final res = await _dio.get('/mss/history');
    return (res.data['data'] as List?) ?? [];
  }

  Future<Response> actApproval(String id, String action, {String? reason}) =>
      _dio.post(
        '/mss/approvals/$id/act',
        data: {'action': action, if (reason != null) 'reason': reason},
      );

  Future<Response> bulkApproval(
    List<String> ids,
    String action, {
    String? reason,
  }) => _dio.post(
    '/mss/approvals/bulk',
    data: {'ids': ids, 'action': action, if (reason != null) 'reason': reason},
  );

  Future<List<dynamic>> team() async {
    final res = await _dio.get('/mss/team');
    return (res.data['data'] as List?) ?? [];
  }

  Future<MssMemberDetail> mssMember(int id) async {
    final res = await _dio.get('/mss/team/$id');
    return MssMemberDetail.fromJson(
      Map<String, dynamic>.from(res.data['data']),
    );
  }

  Future<List<ShiftOption>> mssShifts() async {
    final res = await _dio.get('/mss/shifts');
    final list = (res.data['data'] as List?) ?? [];

    return list
        .map((e) => ShiftOption.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Response> mssAssignShift({
    required int employeeId,
    required String date,
    int? shiftId,
  }) => _dio.post(
    '/mss/schedule',
    data: {'employee_id': employeeId, 'date': date, 'shift_id': shiftId},
  );

  Future<TeamRecap> mssTeamRecap({String? start, String? end}) async {
    final res = await _dio.get(
      '/mss/attendance/recap',
      queryParameters: {
        if (start != null) 'start': start,
        if (end != null) 'end': end,
      },
    );

    return TeamRecap.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<List<int>> mssTeamRecapExport({String? start, String? end}) async {
    final res = await _dio.get<List<int>>(
      '/mss/attendance/recap/export',
      queryParameters: {
        if (start != null) 'start': start,
        if (end != null) 'end': end,
      },
      options: Options(responseType: ResponseType.bytes),
    );

    return res.data ?? <int>[];
  }

  // ---- Documents ----
  Future<List<DocumentItem>> documents() async {
    final res = await _dio.get('/me/documents');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => DocumentItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Response> submitDocument({
    required String name,
    String? type,
    required String filePath,
  }) async {
    final form = FormData.fromMap({
      'name': name,
      if (type != null && type.isNotEmpty) 'type': type,
      'file': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
      ),
    });
    return _dio.post('/me/documents', data: form);
  }

  // ---- Field visits ----
  Future<Paged<FieldVisitItem>> fieldVisits({
    int page = 1,
    String? search,
    String? date,
    int perPage = 20,
  }) async {
    final res = await _dio.get(
      '/me/field-visits',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (date != null && date.isNotEmpty) 'date': date,
      },
    );

    return Paged<FieldVisitItem>.fromJson(
      Map<String, dynamic>.from(res.data as Map),
      FieldVisitItem.fromJson,
    );
  }

  Future<Response> submitFieldVisit({
    required String visitDate,
    required String location,
    String? clientName,
    String? purpose,
    String? notes,
    double? latitude,
    double? longitude,
    List<String> photoPaths = const [],
    List<String> tasks = const [],
    List<String?> taskNotes = const [],
    List<String?> taskBeforePaths = const [],
    List<String?> taskAfterPaths = const [],
  }) async {
    final form = FormData.fromMap({
      'visit_date': visitDate,
      'location': location,
      if (clientName != null && clientName.isNotEmpty)
        'client_name': clientName,
      if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      // Indexed keys (tasks[0], tasks[1], …) so Laravel reads the checklist as
      // an array — a bare List value is serialized as a repeated `tasks` field,
      // which PHP collapses to a single string. The evidence arrays are
      // index-aligned with it: entry N belongs to task N.
      for (var i = 0; i < tasks.length; i++) 'tasks[$i]': tasks[i],
      for (var i = 0; i < taskNotes.length; i++)
        if (taskNotes[i] != null && taskNotes[i]!.isNotEmpty)
          'task_notes[$i]': taskNotes[i],
      for (var i = 0; i < taskBeforePaths.length; i++)
        if (taskBeforePaths[i] != null)
          'task_before[$i]': await MultipartFile.fromFile(
            taskBeforePaths[i]!,
            filename: taskBeforePaths[i]!.split('/').last,
          ),
      for (var i = 0; i < taskAfterPaths.length; i++)
        if (taskAfterPaths[i] != null)
          'task_after[$i]': await MultipartFile.fromFile(
            taskAfterPaths[i]!,
            filename: taskAfterPaths[i]!.split('/').last,
          ),
      // Indexed keys (photos[0], …) so Laravel reads them as an array of uploads.
      for (var i = 0; i < photoPaths.length; i++)
        'photos[$i]': await MultipartFile.fromFile(
          photoPaths[i],
          filename: photoPaths[i].split('/').last,
        ),
    });
    return _dio.post('/me/field-visits', data: form);
  }

  Future<Response> uploadVisitTaskAfter({
    required int visitId,
    required int taskId,
    required String imagePath,
  }) async {
    final form = FormData.fromMap({
      'after': await MultipartFile.fromFile(
        imagePath,
        filename: imagePath.split('/').last,
      ),
    });

    return _dio.post(
      '/me/field-visits/$visitId/tasks/$taskId/after',
      data: form,
    );
  }

  // ---- Shift swaps ----
  Future<List<ShiftSwapItem>> shiftSwaps() async {
    final res = await _dio.get('/me/shift-swaps');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => ShiftSwapItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Colleague>> swapColleagues() async {
    final res = await _dio.get('/me/shift-swaps/colleagues');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => Colleague.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Response> submitShiftSwap({
    required int targetId,
    required String date,
    String? reason,
  }) => _dio.post(
    '/me/shift-swaps',
    data: {
      'target_id': targetId,
      'date': date,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    },
  );

  // ---- AI Assistant ----
  Future<AiSession> aiSession() async {
    final res = await _dio.get('/me/ai');
    return AiSession.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<List<AiChatMessage>> aiMessages(int conversationId) async {
    final res = await _dio.get('/me/ai/conversations/$conversationId');
    final list = (res.data['messages'] as List?) ?? [];
    return list
        .map((e) => AiChatMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Sends a message and returns the assistant reply. The model may loop over
  /// data tools, so this call needs a longer receive window than the default.
  Future<Response> aiChat(String message, {int? conversationId}) => _dio.post(
    '/me/ai/chat',
    data: {
      'message': message,
      if (conversationId != null) 'conversation_id': conversationId,
    },
    options: Options(receiveTimeout: const Duration(seconds: 90)),
  );

  Future<void> aiDeleteConversation(int conversationId) =>
      _dio.delete('/me/ai/conversations/$conversationId');
}
