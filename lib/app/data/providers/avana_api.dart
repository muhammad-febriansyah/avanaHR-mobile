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
import '../models/meeting.dart';
import '../models/mss.dart';
import '../models/onboarding_slide.dart';
import '../models/payslip.dart';
import '../models/profile.dart';
import '../models/schedule.dart';
import '../models/two_factor_status.dart';
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

  /// Second half of a login for an account carrying two-factor. The device
  /// details are not resent: the server kept them with the challenge.
  Future<Response> twoFactor(
    String challengeToken, {
    String? code,
    String? recoveryCode,
  }) => _dio.post(
    '/auth/two-factor',
    data: {
      'challenge_token': challengeToken,
      if (code != null) 'code': code,
      if (recoveryCode != null) 'recovery_code': recoveryCode,
    },
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

  /// Register the device's Firebase (FCM) push token with the backend.
  Future<void> registerFcmToken({
    required String deviceId,
    required String token,
  }) => _dio.post(
    '/me/security/fcm-token',
    data: {'device_id': deviceId, 'fcm_token': token},
  );

  // ---- ESS read ----
  Future<Profile> profile() async {
    final res = await _dio.get('/me/profile');
    return Profile.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// Update the caller's self-editable personal fields. Empty strings are sent
  /// as-is; Laravel converts them to null (all fields are nullable server-side).
  Future<Profile> updateProfile({
    String? phone,
    String? address,
    String? email,
    String? nik,
    String? gender,
    String? birthPlace,
    String? birthDate,
    String? religion,
    String? maritalStatus,
  }) async {
    final res = await _dio.put(
      '/me/profile',
      data: {
        'phone': phone,
        'address': address,
        'email': email,
        'nik': nik,
        'gender': gender,
        'birth_place': birthPlace,
        'birth_date': birthDate,
        'religion': religion,
        'marital_status': maritalStatus,
      },
    );
    return Profile.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// Upload / replace the caller's profile photo (avatar). Multipart POST.
  Future<Profile> updateProfilePhoto(String imagePath) async {
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(
        imagePath,
        filename: imagePath.split('/').last,
      ),
    });
    final res = await _dio.post('/me/profile/photo', data: form);
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

  // ---- Two-factor management ----
  //
  // Every one of these answers with the same status shape, so the caller always
  // learns where the account stands without a second round trip.

  Future<TwoFactorStatus> twoFactorStatus() =>
      _twoFactor(() => _dio.get('/me/security/two-factor'));

  /// Mint the secret. The account is not protected until [confirmTwoFactor].
  Future<TwoFactorStatus> enableTwoFactor(String currentPassword) => _twoFactor(
    () => _dio.post(
      '/me/security/two-factor',
      data: {'current_password': currentPassword},
    ),
  );

  Future<TwoFactorStatus> confirmTwoFactor(String code) => _twoFactor(
    () => _dio.post('/me/security/two-factor/confirm', data: {'code': code}),
  );

  Future<TwoFactorStatus> disableTwoFactor(String currentPassword) =>
      _twoFactor(
        () => _dio.delete(
          '/me/security/two-factor',
          data: {'current_password': currentPassword},
        ),
      );

  Future<TwoFactorStatus> regenerateRecoveryCodes(String currentPassword) =>
      _twoFactor(
        () => _dio.post(
          '/me/security/two-factor/recovery-codes',
          data: {'current_password': currentPassword},
        ),
      );

  /// Run a two-factor call and read the status off it.
  ///
  /// The client treats anything under 500 as a response, so a 422 arrives here
  /// rather than as a throw — it is turned into one so callers have a single
  /// failure path.
  Future<TwoFactorStatus> _twoFactor(Future<Response> Function() call) async {
    final res = await call();

    if (res.statusCode != 200 || res.data is! Map) {
      throw DioException.badResponse(
        statusCode: res.statusCode ?? 0,
        requestOptions: res.requestOptions,
        response: res,
      );
    }

    return TwoFactorStatus.fromJson(
      Map<String, dynamic>.from(res.data['data']),
    );
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

  /// A single-use liveness nonce, valid for two minutes.
  ///
  /// Only tenants with "wajib tantangan liveness" on need it, and for them the
  /// server refuses any clock that arrives without one. Returns null when the
  /// challenge cannot be issued, so the caller can decide whether to submit
  /// anyway and let the server have the final word.
  Future<String?> attendanceChallenge() async {
    try {
      final res = await _dio.post('/me/attendance/challenge');

      return res.data['data']?['nonce'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ---- ESS write ----
  Future<Response> clock({
    required String type,
    String? workMode,
    double? latitude,
    double? longitude,
    String? deviceId,
    bool? isMockLocation,
    bool? isRooted,
    bool? isEmulator,
    String? clockedAt,
    String? selfiePath,
    String? nonce,
  }) async {
    final fields = <String, dynamic>{
      'type': type,
      if (workMode != null) 'work_mode': workMode,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (deviceId != null) 'device_id': deviceId,
      if (isMockLocation != null) 'is_mock_location': isMockLocation,
      if (isRooted != null) 'is_rooted': isRooted,
      if (isEmulator != null) 'is_emulator': isEmulator,
      if (clockedAt != null) 'clocked_at': clockedAt,
      if (nonce != null) 'nonce': nonce,
    };

    // No selfie -> plain JSON. With a selfie -> multipart so Laravel can send
    // the same accepted frame to the private Python recognition service.
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
    final form = FormData();
    fields.forEach((key, value) {
      if (value is bool) {
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

  /// Everyone in the tenant celebrating a birthday today. The dashboard only
  /// carries a preview slice, so the "lihat semua" sheet fetches the full list.
  Future<List<BirthdayPerson>> birthdays() async {
    final res = await _dio.get('/me/birthdays');

    return ((res.data['data'] as List?) ?? [])
        .map((e) => BirthdayPerson.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Response> moodToday() => _dio.get('/me/mood');

  Future<Response> submitMood(String mood) =>
      _dio.post('/me/mood', data: {'mood': mood});

  Future<WorkLocations> workLocations() async {
    final res = await _dio.get('/me/work-locations');
    final list = (res.data['data'] as List?) ?? [];

    return WorkLocations(
      items: list
          .map((e) => WorkLocationItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      scope: (res.data['scope'] as String?) ?? 'assigned',
    );
  }

  // ---- Activity feed (Riwayat) ----
  Future<List<ActivityItem>> activities({DateTime? from, DateTime? to}) async {
    String formatDate(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';

    final res = await _dio.get(
      '/me/activities',
      queryParameters: {
        if (from != null) 'from': formatDate(from),
        if (to != null) 'to': formatDate(to),
      },
    );
    final list = (res.data['data'] as List?) ?? [];

    return list
        .map((e) => ActivityItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---- Face recognition ----
  Future<Response> faceStatus() => _dio.get('/me/face');

  Future<Response> deleteFace() => _dio.delete('/me/face');

  Future<Response> enrollFace(List<String> imagePaths) async {
    final form = FormData();
    for (var index = 0; index < imagePaths.length; index++) {
      form.files.add(
        MapEntry(
          'images[]',
          await MultipartFile.fromFile(
            imagePaths[index],
            filename: 'face_${index + 1}.jpg',
          ),
        ),
      );
    }

    return _dio.post('/me/face/enroll', data: form);
  }

  /// Ship a batch of face-scan diagnostics so a failure that only happens on
  /// certain devices is visible server-side instead of only on the phone.
  Future<Response> logFaceScans({
    required List<Map<String, dynamic>> events,
    required Map<String, dynamic> device,
  }) => _dio.post('/me/face/log', data: {'events': events, 'device': device});

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
  /// The employee's overtime requests together with the company's rounding
  /// rule, so the filing sheet can preview the hours payroll will actually pay.
  Future<OvertimeBoard> overtimes() async {
    final res = await _dio.get('/me/overtime');
    final list = (res.data['data'] as List?) ?? [];
    final policy = res.data['policy'];

    return OvertimeBoard(
      items: list
          .map((e) => OvertimeItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      policy: policy is Map
          ? OvertimePolicy.fromJson(Map<String, dynamic>.from(policy))
          : const OvertimePolicy(),
    );
  }

  /// Overtime is filed as a range; the server derives the hours from it, so
  /// the app never sends a total of its own.
  Future<Response> submitOvertime({
    required String date,
    required String startTime,
    required String endTime,
    String? reason,
  }) => _dio.post(
    '/me/overtime',
    data: {
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      if (reason != null) 'reason': reason,
    },
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

  // ---- Social wall ----
  Future<List<SocialCategoryItem>> socialCategories() async {
    final res = await _dio.get('/me/social/categories');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => SocialCategoryItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Paged<SocialPostItem>> socialFeed({
    int page = 1,
    int? categoryId,
    String sort = 'latest',
  }) async {
    final res = await _dio.get(
      '/me/social/feed',
      queryParameters: {
        'page': page,
        'sort': sort,
        if (categoryId != null) 'category': categoryId,
      },
    );

    return Paged.fromJson(
      Map<String, dynamic>.from(res.data),
      SocialPostItem.fromJson,
    );
  }

  Future<Response> createSocialPost({
    required String body,
    int? categoryId,
    String? imagePath,
  }) async {
    final form = FormData.fromMap({
      'body': body,
      if (categoryId != null) 'social_category_id': categoryId,
      if (imagePath != null) 'image': await MultipartFile.fromFile(imagePath),
    });

    return _dio.post('/me/social/posts', data: form);
  }

  Future<SocialPostItem> socialPost(int id) async {
    final res = await _dio.get('/me/social/posts/$id');
    return SocialPostItem.fromJson(
      Map<String, dynamic>.from(res.data['data'] as Map),
    );
  }

  Future<Response> updateSocialPost({
    required int id,
    required String body,
    int? categoryId,
    String? imagePath,
    bool removeImage = false,
  }) async {
    final form = FormData.fromMap({
      'body': body,
      if (categoryId != null) 'social_category_id': categoryId,
      if (removeImage) 'remove_image': 1,
      if (imagePath != null) 'image': await MultipartFile.fromFile(imagePath),
    });

    return _dio.post('/me/social/posts/$id/update', data: form);
  }

  Future<Response> reportSocialPost(int id, String? reason) => _dio.post(
    '/me/social/posts/$id/report',
    data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
  );

  Future<Response> deleteSocialPost(int id) =>
      _dio.delete('/me/social/posts/$id');

  /// Returns `{liked, likes_count}` as the server counted it.
  Future<Map<String, dynamic>> toggleSocialLike(int id) async {
    final res = await _dio.post('/me/social/posts/$id/like');
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  Future<List<SocialCommentItem>> socialComments(int postId) async {
    final res = await _dio.get('/me/social/posts/$postId/comments');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => SocialCommentItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Response> createSocialComment(
    int postId,
    String body, {
    int? parentId,
  }) => _dio.post(
    '/me/social/posts/$postId/comments',
    data: {'body': body, if (parentId != null) 'parent_id': parentId},
  );

  Future<Response> deleteSocialComment(int id) =>
      _dio.delete('/me/social/comments/$id');

  Future<List<SocialLeaderItem>> socialLeaderboard({
    String range = 'all',
    int limit = 20,
  }) async {
    final res = await _dio.get(
      '/me/social/leaderboard',
      queryParameters: {'range': range, 'limit': limit},
    );
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => SocialLeaderItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---- Employee of the Month ----
  Future<EotmSnapshot> eotm() async {
    final res = await _dio.get('/me/eotm');
    return EotmSnapshot.fromJson(
      Map<String, dynamic>.from(res.data['data'] as Map),
    );
  }

  Future<List<EotmNomineeItem>> eotmNominees({String? search}) async {
    final res = await _dio.get(
      '/me/eotm/nominees',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => EotmNomineeItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Response> eotmVote({
    required int nomineeId,
    int? coreValueId,
    String? reason,
  }) => _dio.post(
    '/me/eotm/vote',
    data: {
      'nominee_employee_id': nomineeId,
      if (coreValueId != null) 'eotm_core_value_id': coreValueId,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    },
  );

  // ---- SOP ----
  Future<List<SopItem>> sops() async {
    final res = await _dio.get('/me/sop');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => SopItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Raw PDF bytes for one SOP; the server re-checks visibility per record.
  Future<List<int>> sopPdf(int id) async {
    final res = await _dio.get<List<int>>(
      '/me/sop/$id/download',
      options: Options(responseType: ResponseType.bytes),
    );

    return res.data ?? <int>[];
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

  // ---- Personal AI token wallet ----

  /// Balance, packs on sale, and this person's own purchases.
  Future<Map<String, dynamic>> aiTokens() async {
    final res = await _dio.get('/me/ai/tokens');
    return Map<String, dynamic>.from(res.data['data'] ?? {});
  }

  /// Opens a pending order and returns it with the URL to pay it.
  Future<Map<String, dynamic>> aiBuyTokens(int packId) async {
    final res = await _dio.post('/me/ai/tokens', data: {'pack_id': packId});
    return Map<String, dynamic>.from(res.data['data'] ?? {});
  }

  /// Asks whether an order has been paid. The server verifies with the gateway
  /// on the way past, so this settles a payment the webhook has not reached yet.
  Future<Map<String, dynamic>> aiTokenOrder(String orderNumber) async {
    final res = await _dio.get('/me/ai/tokens/$orderNumber');
    return Map<String, dynamic>.from(res.data['data'] ?? {});
  }

  // ---- AI Recorder (Rapat & Transkrip) ----

  /// Fail loudly on a rejected request.
  ///
  /// The client treats anything under 500 as a normal response, so a 422 or a
  /// 409 arrives looking like success and its body reads as an empty payload.
  /// For most screens that only means a blank list, but the recorder builds a
  /// WebSocket URL out of it and fails somewhere unrelated with the server's
  /// actual explanation thrown away. Every recorder call goes through here so
  /// the reason the server gave is the reason the user is shown.
  Response _ensureOk(Response res) {
    final status = res.statusCode ?? 0;

    if (status < 200 || status >= 300) {
      throw DioException.badResponse(
        statusCode: status,
        requestOptions: res.requestOptions,
        response: res,
      );
    }

    return res;
  }

  /// Whether recording is possible, and what it costs — asked before the
  /// microphone is ever opened.
  Future<MeetingRecorderStatus> meetingStatus() async {
    final res = _ensureOk(await _dio.get('/me/meetings/status'));
    return MeetingRecorderStatus.fromJson(
      Map<String, dynamic>.from(res.data['data'] ?? {}),
    );
  }

  Future<List<MeetingItem>> meetings({String? search, int page = 1}) async {
    final res = _ensureOk(
      await _dio.get(
        '/me/meetings',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          'page': page,
        },
      ),
    );

    return ((res.data['data'] as List?) ?? [])
        .map((e) => MeetingItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<MeetingDetail> meeting(int id) async {
    final res = _ensureOk(await _dio.get('/me/meetings/$id'));
    return MeetingDetail.fromJson(
      Map<String, dynamic>.from(res.data['data'] ?? {}),
    );
  }

  /// Open a recording. Throws when the wallet cannot fund it — better now than
  /// forty minutes into a meeting.
  Future<MeetingItem> startMeeting({
    required String title,
    String? location,
    List<int> participantIds = const [],
  }) async {
    final res = await _dio.post(
      '/me/meetings',
      data: {
        'title': title,
        if (location != null && location.isNotEmpty) 'location': location,
        if (participantIds.isNotEmpty) 'participant_ids': participantIds,
      },
    );

    _ensureOk(res);

    return MeetingItem.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// A fresh credential for the listening socket. Re-asked as the old one
  /// nears expiry; the provider's project key never leaves the server.
  Future<MeetingSttGrant> meetingSttGrant(int id) async {
    final res = _ensureOk(await _dio.get('/me/meetings/$id/stt-token'));
    return MeetingSttGrant.fromJson(
      Map<String, dynamic>.from(res.data['data'] ?? {}),
    );
  }

  /// Hand over the text settled since the last heartbeat, and the clock.
  ///
  /// Returns the server's verdict. `stop` comes back true — with HTTP 409 —
  /// when the wallet has run dry or the duration ceiling is hit, which is the
  /// signal to close the socket. Resending a batch is safe: the server keys
  /// segments on their offset and bills the same audio only once.
  Future<Map<String, dynamic>> pushMeetingSegments({
    required int id,
    required List<PendingSegment> segments,
    required int elapsedMs,
  }) async {
    // Throws on 409, which is how the server says "stop" — the caller catches
    // it and closes the socket. Wrapping it also means an unexpected refusal
    // mid-recording surfaces instead of being read as an empty result.
    final res = _ensureOk(
      await _dio.post(
        '/me/meetings/$id/segments',
        data: {
          'elapsed_ms': elapsedMs,
          'segments': segments.map((s) => s.toJson()).toList(),
        },
      ),
    );

    return Map<String, dynamic>.from(res.data['data'] ?? {});
  }

  /// Stop recording; the summary is built on a queue and pushed when ready.
  Future<MeetingItem> stopMeeting({
    required int id,
    required int elapsedMs,
  }) async {
    final res = _ensureOk(
      await _dio.post('/me/meetings/$id/stop', data: {'elapsed_ms': elapsedMs}),
    );

    return MeetingItem.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// Upload the keepsake audio after the socket closes, so a slow upload never
  /// holds up the transcript the server already has.
  Future<void> uploadMeetingAudio({
    required int id,
    required String filePath,
  }) async {
    _ensureOk(
      await _dio.post(
        '/me/meetings/$id/audio',
        data: FormData.fromMap({
          'audio': await MultipartFile.fromFile(filePath),
        }),
      ),
    );
  }

  /// Tick a follow-up off, or put it back. Returns the meeting as it now
  /// stands, so the screen redraws from the server rather than from a guess.
  Future<MeetingDetail> setMeetingActionItemStatus({
    required int meetingId,
    required int actionItemId,
    required bool done,
  }) async {
    final res = _ensureOk(
      await _dio.put(
        '/me/meetings/$meetingId/action-items/$actionItemId',
        data: {'status': done ? 'done' : 'open'},
      ),
    );

    return MeetingDetail.fromJson(
      Map<String, dynamic>.from(res.data['data'] ?? {}),
    );
  }

  Future<MeetingDetail> addMeetingActionItem({
    required int meetingId,
    required String text,
  }) async {
    final res = _ensureOk(
      await _dio.post(
        '/me/meetings/$meetingId/action-items',
        data: {'text': text},
      ),
    );

    return MeetingDetail.fromJson(
      Map<String, dynamic>.from(res.data['data'] ?? {}),
    );
  }

  /// Ask for the summary to be built again. Spends tokens, so the server
  /// refuses here rather than failing later on a worker.
  Future<MeetingDetail> reprocessMeeting(int id) async {
    final res = _ensureOk(await _dio.post('/me/meetings/$id/reprocess'));

    return MeetingDetail.fromJson(
      Map<String, dynamic>.from(res.data['data'] ?? {}),
    );
  }
}
