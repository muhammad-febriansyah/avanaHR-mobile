// Employee self-service models for the AvanaHR mobile API (all {data}-enveloped).

import '../../core/config/env.dart';
import '../../core/utils/formats.dart';

/// Normalize an API date/datetime string to a clean Indonesian "15 Jul 2026"
/// label, dropping any time component. Returns '' for null/empty.
String fmtDate(dynamic value) => formatTanggal(value, fallback: '');

/// A single page of a `{data, meta}` paginated list response. Carries the rows
/// plus enough paging state for infinite scroll to know when to stop.
class Paged<T> {
  final List<T> items;
  final int currentPage;
  final int lastPage;

  const Paged({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  bool get hasMore => currentPage < lastPage;

  /// Build from a raw `{data:[...], meta:{current_page,last_page}}` map.
  factory Paged.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final list = (json['data'] as List?) ?? const [];
    final meta = (json['meta'] as Map?) ?? const {};

    return Paged<T>(
      items: list
          .map((e) => parse(Map<String, dynamic>.from(e as Map)))
          .toList(),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
    );
  }
}

class LeaveType {
  final int id;
  final String code;
  final String name;
  final int defaultQuota;
  final bool requiresAttachment;

  LeaveType({
    required this.id,
    required this.code,
    required this.name,
    required this.defaultQuota,
    required this.requiresAttachment,
  });

  factory LeaveType.fromJson(Map<String, dynamic> j) => LeaveType(
    id: j['id'],
    code: j['code'] ?? '',
    name: j['name'] ?? '',
    defaultQuota: (j['default_quota'] ?? 0) is int
        ? j['default_quota']
        : int.tryParse('${j['default_quota']}') ?? 0,
    requiresAttachment: j['requires_attachment'] ?? false,
  );
}

class LeaveRequestItem {
  final int id;
  final String? leaveType;
  final String startDate;
  final String endDate;
  final int totalDays;
  final String? reason;
  final String status;

  LeaveRequestItem({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.status,
    this.leaveType,
    this.reason,
  });

  factory LeaveRequestItem.fromJson(Map<String, dynamic> j) => LeaveRequestItem(
    id: j['id'],
    leaveType: j['leave_type'],
    startDate: fmtDate(j['start_date']),
    endDate: fmtDate(j['end_date']),
    totalDays: (j['total_days'] ?? 0) is int
        ? j['total_days']
        : int.tryParse('${j['total_days']}') ?? 0,
    reason: j['reason'],
    status: j['status'] ?? '',
  );
}

class OvertimeItem {
  final int id;
  final String date;
  final double hours;
  final String? reason;
  final String status;

  OvertimeItem({
    required this.id,
    required this.date,
    required this.hours,
    required this.status,
    this.reason,
  });

  factory OvertimeItem.fromJson(Map<String, dynamic> j) => OvertimeItem(
    id: j['id'],
    date: fmtDate(j['date']),
    hours: (j['hours'] ?? 0).toDouble(),
    reason: j['reason'],
    status: j['status'] ?? '',
  );
}

class PermissionItem {
  final int id;
  final String startDate;
  final String endDate;
  final String type;
  final String? startTime;
  final String? endTime;
  final String? reason;
  final String status;

  PermissionItem({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.type,
    required this.status,
    this.startTime,
    this.endTime,
    this.reason,
  });

  /// Izin spanning one day reads as a single date; longer ones as a range.
  String get dateLabel =>
      startDate == endDate ? startDate : '$startDate – $endDate';

  factory PermissionItem.fromJson(Map<String, dynamic> j) => PermissionItem(
    id: j['id'],
    startDate: fmtDate(j['start_date']),
    endDate: fmtDate(j['end_date']),
    type: j['type'] ?? '',
    startTime: j['start_time'],
    endTime: j['end_time'],
    reason: j['reason'],
    status: j['status'] ?? '',
  );
}

class WfhItem {
  final int id;
  final String startDate;
  final String endDate;
  final String? reason;
  final String status;

  WfhItem({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.reason,
  });

  factory WfhItem.fromJson(Map<String, dynamic> j) => WfhItem(
    id: j['id'],
    startDate: fmtDate(j['start_date']),
    endDate: fmtDate(j['end_date']),
    reason: j['reason'],
    status: j['status'] ?? '',
  );
}

class AttendanceCorrectionItem {
  final int id;
  final String date;
  final String? clockIn;
  final String? clockOut;
  final String? reason;
  final String status;

  AttendanceCorrectionItem({
    required this.id,
    required this.date,
    required this.status,
    this.clockIn,
    this.clockOut,
    this.reason,
  });

  factory AttendanceCorrectionItem.fromJson(Map<String, dynamic> j) => AttendanceCorrectionItem(
    id: j['id'],
    date: fmtDate(j['date']),
    clockIn: j['requested_clock_in'],
    clockOut: j['requested_clock_out'],
    reason: j['reason'],
    status: j['status'] ?? '',
  );
}

class ReimbursementItem {
  final int id;
  final String category;
  final String? title;
  final int amount;
  final String date;
  final String status;

  ReimbursementItem({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    required this.status,
    this.title,
  });

  factory ReimbursementItem.fromJson(Map<String, dynamic> j) =>
      ReimbursementItem(
        id: j['id'],
        category: j['category'] ?? '',
        title: j['title'],
        amount: (j['amount'] ?? 0) is int
            ? j['amount']
            : int.tryParse('${j['amount']}') ?? 0,
        date: fmtDate(j['date']),
        status: j['status'] ?? '',
      );
}

class AnnouncementItem {
  final int id;
  final String title;
  final String? body;
  final String? category;
  final bool pinned;
  final String? publishedAt;

  AnnouncementItem({
    required this.id,
    required this.title,
    required this.pinned,
    this.body,
    this.category,
    this.publishedAt,
  });

  factory AnnouncementItem.fromJson(Map<String, dynamic> j) => AnnouncementItem(
    id: j['id'],
    title: j['title'] ?? '',
    body: j['body'],
    category: j['category'],
    pinned: j['pinned'] ?? false,
    publishedAt: j['published_at'],
  );
}

class DocumentItem {
  final int id;
  final String name;
  final String? type;
  final String? url;
  final int size;
  final String? uploadedAt;

  DocumentItem({
    required this.id,
    required this.name,
    required this.size,
    this.type,
    this.url,
    this.uploadedAt,
  });

  factory DocumentItem.fromJson(Map<String, dynamic> j) => DocumentItem(
    id: j['id'],
    name: j['name'] ?? '',
    type: j['type'],
    url: j['url'],
    size: (j['size'] ?? 0) is int
        ? j['size']
        : int.tryParse('${j['size']}') ?? 0,
    uploadedAt: j['uploaded_at'],
  );
}

class FieldVisitItem {
  final int id;
  final String visitDate;
  final String location;
  final String? clientName;
  final String? purpose;
  final String? notes;
  final List<String> photoUrls;
  final String status;

  FieldVisitItem({
    required this.id,
    required this.visitDate,
    required this.location,
    required this.status,
    this.clientName,
    this.purpose,
    this.notes,
    this.photoUrls = const [],
  });

  factory FieldVisitItem.fromJson(Map<String, dynamic> j) => FieldVisitItem(
    id: j['id'],
    visitDate: fmtDate(j['visit_date']),
    location: j['location'] ?? '',
    clientName: j['client_name'],
    purpose: j['purpose'],
    notes: j['notes'],
    photoUrls: ((j['photo_urls'] as List?) ?? [])
        .map((e) => Env.resolveMedia(e as String?))
        .whereType<String>()
        .toList(),
    status: j['status'] ?? '',
  );
}

class ShiftSwapItem {
  final int id;
  final String date;
  final String? requester;
  final String? target;
  final String direction;
  final String? reason;
  final String status;

  ShiftSwapItem({
    required this.id,
    required this.date,
    required this.direction,
    required this.status,
    this.requester,
    this.target,
    this.reason,
  });

  factory ShiftSwapItem.fromJson(Map<String, dynamic> j) => ShiftSwapItem(
    id: j['id'],
    date: fmtDate(j['date']),
    requester: j['requester'],
    target: j['target'],
    direction: j['direction'] ?? 'outgoing',
    reason: j['reason'],
    status: j['status'] ?? '',
  );
}

class Colleague {
  final int id;
  final String name;
  final String? employeeNumber;

  Colleague({required this.id, required this.name, this.employeeNumber});

  factory Colleague.fromJson(Map<String, dynamic> j) => Colleague(
    id: j['id'],
    name: j['name'] ?? '',
    employeeNumber: j['employee_number'],
  );
}

/// A settlement (Settlement Perdin) as listed on `/me/settlements`.
class SettlementItem {
  final int id;
  final String number;
  final String title;
  final String? destination;
  final int total;
  final String status;
  final String submissionDate;
  final String? paidAt;

  SettlementItem({
    required this.id,
    required this.number,
    required this.title,
    required this.total,
    required this.status,
    required this.submissionDate,
    this.destination,
    this.paidAt,
  });

  factory SettlementItem.fromJson(Map<String, dynamic> j) => SettlementItem(
    id: j['id'],
    number: j['number'] ?? '',
    title: j['title'] ?? '',
    destination: j['destination'],
    total: _asInt(j['total']),
    status: j['status'] ?? '',
    submissionDate: fmtDate(j['submission_date']),
    paidAt: j['paid_at'],
  );
}

/// Where the trip went and for how long. Every field is optional — a claim for
/// an operational cost carries no travel leg at all.
class SettlementTravel {
  final String? destination;
  final String? startDate;
  final String? endDate;
  final int? days;
  final double? latitude;
  final double? longitude;

  SettlementTravel({
    this.destination,
    this.startDate,
    this.endDate,
    this.days,
    this.latitude,
    this.longitude,
  });

  factory SettlementTravel.fromJson(Map<String, dynamic> j) => SettlementTravel(
    destination: j['destination'],
    startDate: j['start_date'],
    endDate: j['end_date'],
    days: j['days'],
    latitude: _asDouble(j['latitude']),
    longitude: _asDouble(j['longitude']),
  );

  bool get hasPin => latitude != null && longitude != null;

  /// "18 Jul 2026 — 21 Jul 2026 (4 hari)", or null when the dates are missing.
  String? get rangeLabel {
    if (startDate == null || endDate == null) {
      return null;
    }
    final range = '${formatTanggal(startDate)} — ${formatTanggal(endDate)}';

    return days == null ? range : '$range ($days hari)';
  }
}

/// One expense line on a settlement.
class SettlementLine {
  final int id;
  final String description;
  final String? detail;
  final String categoryLabel;
  final String icon;
  final int amount;

  SettlementLine({
    required this.id,
    required this.description,
    required this.categoryLabel,
    required this.icon,
    required this.amount,
    this.detail,
  });

  factory SettlementLine.fromJson(Map<String, dynamic> j) => SettlementLine(
    id: j['id'],
    description: j['description'] ?? '',
    detail: j['detail'],
    categoryLabel: j['category_label'] ?? '',
    icon: j['icon'] ?? 'receipt',
    amount: _asInt(j['amount']),
  );
}

/// One supporting document (receipt scan) attached to a settlement.
class SettlementDocument {
  final int id;
  final String name;
  final String? url;

  SettlementDocument({required this.id, required this.name, this.url});

  factory SettlementDocument.fromJson(Map<String, dynamic> j) =>
      SettlementDocument(
        id: j['id'],
        name: j['name'] ?? 'Dokumen',
        url: Env.resolveMedia(j['url']),
      );
}

/// One step of the submit → manager → finance → paid trail.
class SettlementStep {
  final String key;
  final String label;
  final bool done;
  final String? at;

  SettlementStep({
    required this.key,
    required this.label,
    required this.done,
    this.at,
  });

  factory SettlementStep.fromJson(Map<String, dynamic> j) => SettlementStep(
    key: j['key'] ?? '',
    label: j['label'] ?? '',
    done: j['done'] == true,
    at: j['at'],
  );
}

/// A settlement in full, as returned by `/me/settlements/{id}`.
class SettlementDetail {
  final SettlementItem header;
  final int subtotal;
  final int taxAmount;
  final String? department;
  final String? notes;
  final String? rejectionReason;
  final SettlementTravel travel;
  final BankAccountInfo payoutAccount;
  final List<SettlementLine> items;
  final List<SettlementDocument> documents;
  final List<SettlementStep> timeline;

  SettlementDetail({
    required this.header,
    required this.subtotal,
    required this.taxAmount,
    required this.travel,
    required this.payoutAccount,
    required this.items,
    required this.documents,
    required this.timeline,
    this.department,
    this.notes,
    this.rejectionReason,
  });

  factory SettlementDetail.fromJson(Map<String, dynamic> j) => SettlementDetail(
    header: SettlementItem.fromJson(j),
    subtotal: _asInt(j['subtotal']),
    taxAmount: _asInt(j['tax_amount']),
    department: j['department'],
    notes: j['notes'],
    rejectionReason: j['rejection_reason'],
    travel: SettlementTravel.fromJson(
      Map<String, dynamic>.from(j['travel'] ?? {}),
    ),
    payoutAccount: BankAccountInfo.fromJson(
      Map<String, dynamic>.from(j['payout_account'] ?? {}),
    ),
    items: ((j['items'] as List?) ?? [])
        .map((e) => SettlementLine.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    documents: ((j['documents'] as List?) ?? [])
        .map((e) => SettlementDocument.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    timeline: ((j['timeline'] as List?) ?? [])
        .map((e) => SettlementStep.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

/// The bank account a settlement pays out to.
class BankAccountInfo {
  final String? bankName;
  final String? accountNumber;
  final String? accountHolder;
  final String? swift;

  BankAccountInfo({
    this.bankName,
    this.accountNumber,
    this.accountHolder,
    this.swift,
  });

  factory BankAccountInfo.fromJson(Map<String, dynamic> j) => BankAccountInfo(
    bankName: j['bank_name'],
    accountNumber: j['account_number'],
    accountHolder: j['account_holder'],
    swift: j['swift'],
  );

  bool get isEmpty => bankName == null && accountNumber == null;
}

/// The API sends money as a JSON number; be forgiving if it arrives as a string.
int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0);

double? _asDouble(dynamic v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

/// A cash advance (uang muka) as listed on `/me/cash-advances`.
class CashAdvanceItem {
  final int id;
  final int amount;
  final String purpose;
  final String status;
  final String statusLabel;
  final String requestDate;
  final String neededDate;
  final String? disbursedAt;

  CashAdvanceItem({
    required this.id,
    required this.amount,
    required this.purpose,
    required this.status,
    required this.statusLabel,
    required this.requestDate,
    required this.neededDate,
    this.disbursedAt,
  });

  factory CashAdvanceItem.fromJson(Map<String, dynamic> j) => CashAdvanceItem(
    id: j['id'],
    amount: _asInt(j['amount']),
    purpose: j['purpose'] ?? '',
    status: j['status'] ?? '',
    statusLabel: j['status_label'] ?? '',
    requestDate: fmtDate(j['request_date']),
    neededDate: fmtDate(j['needed_date']),
    disbursedAt: j['disbursed_at'],
  );
}

/// A cash advance in full, as returned by `/me/cash-advances/{id}`.
class CashAdvanceDetail {
  final CashAdvanceItem header;
  final String? reason;
  final String? disbursementMethod;
  final String? disbursementReference;
  final List<SettlementStep> timeline;

  CashAdvanceDetail({
    required this.header,
    required this.timeline,
    this.reason,
    this.disbursementMethod,
    this.disbursementReference,
  });

  factory CashAdvanceDetail.fromJson(Map<String, dynamic> j) =>
      CashAdvanceDetail(
        header: CashAdvanceItem.fromJson(j),
        reason: j['reason'],
        disbursementMethod: j['disbursement_method'],
        disbursementReference: j['disbursement_reference'],
        timeline: ((j['timeline'] as List?) ?? [])
            .map((e) => SettlementStep.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}
