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

/// A sub-type under a leave type. It has no quota of its own — the days come
/// off the parent's balance — and `subLimit` optionally caps how many of them
/// it may take in a year.
class LeaveSubType {
  final int id;
  final String code;
  final String name;
  final int? subLimit;
  final bool requiresAttachment;

  LeaveSubType({
    required this.id,
    required this.code,
    required this.name,
    required this.requiresAttachment,
    this.subLimit,
  });

  factory LeaveSubType.fromJson(Map<String, dynamic> j) => LeaveSubType(
    id: j['id'],
    code: j['code'] ?? '',
    name: j['name'] ?? '',
    subLimit: j['sub_limit'] == null
        ? null
        : (j['sub_limit'] is int
              ? j['sub_limit']
              : int.tryParse('${j['sub_limit']}')),
    requiresAttachment: j['requires_attachment'] ?? false,
  );

  /// Name with its yearly cap, e.g. "Cuti Bersama (maks 3 hari)".
  String get pickerLabel =>
      subLimit == null ? name : '$name (maks $subLimit hari)';
}

class LeaveType {
  final int id;
  final String code;
  final String name;
  final int defaultQuota;
  final bool requiresAttachment;

  /// Sub-types sharing this type's quota. Empty for an unbranched type.
  final List<LeaveSubType> children;

  LeaveType({
    required this.id,
    required this.code,
    required this.name,
    required this.defaultQuota,
    required this.requiresAttachment,
    this.children = const [],
  });

  factory LeaveType.fromJson(Map<String, dynamic> j) => LeaveType(
    id: j['id'],
    code: j['code'] ?? '',
    name: j['name'] ?? '',
    defaultQuota: (j['default_quota'] ?? 0) is int
        ? j['default_quota']
        : int.tryParse('${j['default_quota']}') ?? 0,
    requiresAttachment: j['requires_attachment'] ?? false,
    children: ((j['children'] as List?) ?? const [])
        .map((e) => LeaveSubType.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );

  /// A branched type only groups its sub-types; the request must name one of
  /// them so the sub-caps still apply.
  bool get isSelectable => children.isEmpty;
}

/// One row of a leave type picker: either a non-selectable group header or a
/// choice. Flutter's dropdown has no `<optgroup>`, so the tree is flattened and
/// headers are rendered as disabled entries.
class LeavePickerEntry {
  final int id;
  final String label;
  final bool isHeader;
  final bool isChild;
  final bool requiresAttachment;

  const LeavePickerEntry({
    required this.id,
    required this.label,
    required this.isHeader,
    required this.isChild,
    required this.requiresAttachment,
  });
}

/// Flatten leave types for a dropdown: unbranched types stay single rows, and a
/// branched one becomes a disabled header followed by its sub-types.
List<LeavePickerEntry> leavePickerEntries(List<LeaveType> types) {
  final entries = <LeavePickerEntry>[];

  for (final type in types) {
    if (type.isSelectable) {
      entries.add(
        LeavePickerEntry(
          id: type.id,
          label: type.name,
          isHeader: false,
          isChild: false,
          requiresAttachment: type.requiresAttachment,
        ),
      );

      continue;
    }

    entries.add(
      LeavePickerEntry(
        // Headers are never submitted; the negative id keeps them distinct
        // from any real leave type id.
        id: -type.id,
        label: type.name,
        isHeader: true,
        isChild: false,
        requiresAttachment: false,
      ),
    );

    for (final child in type.children) {
      entries.add(
        LeavePickerEntry(
          id: child.id,
          label: child.pickerLabel,
          isHeader: false,
          isChild: true,
          requiresAttachment: child.requiresAttachment,
        ),
      );
    }
  }

  return entries;
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

  /// "18:00 – 20:00", or null for requests filed before overtime became a range.
  final String? timeRange;
  final String? reason;
  final String status;

  OvertimeItem({
    required this.id,
    required this.date,
    required this.hours,
    this.timeRange,
    required this.status,
    this.reason,
  });

  factory OvertimeItem.fromJson(Map<String, dynamic> j) => OvertimeItem(
    id: j['id'],
    date: fmtDate(j['date']),
    hours: (j['hours'] ?? 0).toDouble(),
    timeRange: j['time_range'] as String?,
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

  factory AttendanceCorrectionItem.fromJson(Map<String, dynamic> j) =>
      AttendanceCorrectionItem(
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

/// A PDF or image attached to an announcement. The backend decides whether the
/// file is previewable via `is_image`, so the app never has to sniff the URL.
class AnnouncementAttachment {
  final String url;
  final String? name;
  final String? mime;
  final int size;
  final bool isImage;

  AnnouncementAttachment({
    required this.url,
    required this.size,
    required this.isImage,
    this.name,
    this.mime,
  });

  /// Returns null when the payload carries no usable file, so callers can just
  /// null-check the attachment instead of testing the url separately.
  static AnnouncementAttachment? fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return null;
    }

    final url = Env.resolveMedia(j['url'] as String?);
    if (url == null || url.isEmpty) {
      return null;
    }

    return AnnouncementAttachment(
      url: url,
      name: j['name'],
      mime: j['mime'],
      size: (j['size'] ?? 0) is int
          ? j['size']
          : int.tryParse('${j['size']}') ?? 0,
      isImage: j['is_image'] ?? false,
    );
  }

  /// Short label for the file kind, e.g. 'PDF' or 'Gambar'.
  String get kindLabel {
    if (isImage) {
      return 'Gambar';
    }

    final ext = (name ?? '').split('.').last.toUpperCase();

    return ext.isEmpty || ext == (name ?? '').toUpperCase() ? 'Dokumen' : ext;
  }

  /// Human-readable file size, or '' when the backend did not report one.
  String get sizeLabel {
    if (size <= 0) {
      return '';
    }
    if (size >= 1048576) {
      return '${(size / 1048576).toStringAsFixed(1)} MB';
    }
    if (size >= 1024) {
      return '${(size / 1024).toStringAsFixed(0)} KB';
    }

    return '$size B';
  }
}

class AnnouncementItem {
  final int id;
  final String title;
  final String? body;
  final String? category;
  final bool pinned;
  final String? publishedAt;
  final AnnouncementAttachment? attachment;

  AnnouncementItem({
    required this.id,
    required this.title,
    required this.pinned,
    this.body,
    this.category,
    this.publishedAt,
    this.attachment,
  });

  factory AnnouncementItem.fromJson(Map<String, dynamic> j) => AnnouncementItem(
    id: j['id'],
    title: j['title'] ?? '',
    body: j['body'],
    category: j['category'],
    pinned: j['pinned'] ?? false,
    publishedAt: j['published_at'],
    attachment: AnnouncementAttachment.fromJson(
      j['attachment'] == null
          ? null
          : Map<String, dynamic>.from(j['attachment']),
    ),
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
    url: Env.resolveMedia(j['url'] as String?),
    size: (j['size'] ?? 0) is int
        ? j['size']
        : int.tryParse('${j['size']}') ?? 0,
    uploadedAt: j['uploaded_at'],
  );

  /// True when the stored file is a previewable image (by url/name extension).
  bool get isImage {
    final s = (url ?? name).toLowerCase();
    return s.endsWith('.jpg') ||
        s.endsWith('.jpeg') ||
        s.endsWith('.png') ||
        s.endsWith('.webp');
  }
}

/// A company SOP document the signed-in employee is allowed to read.
///
/// Mirrors `Api\SopController@index`. Only documents the server considers
/// visible for this user ever reach the app, so there is no client-side
/// visibility check to keep in step.
class SopItem {
  final int id;
  final String title;
  final String? code;
  final String category;
  final String? summary;
  final String? version;
  final String visibility;
  final String? effectiveDate;
  final String? fileName;
  final bool hasFile;

  SopItem({
    required this.id,
    required this.title,
    required this.category,
    required this.visibility,
    required this.hasFile,
    this.code,
    this.summary,
    this.version,
    this.effectiveDate,
    this.fileName,
  });

  factory SopItem.fromJson(Map<String, dynamic> j) => SopItem(
    id: j['id'],
    title: j['title'] ?? '',
    code: j['code'],
    category: j['category'] ?? 'Umum',
    summary: j['summary'],
    version: j['version'],
    visibility: j['visibility'] ?? 'public',
    effectiveDate: j['effective_date'],
    fileName: j['file_name'],
    hasFile: j['has_file'] == true,
  );

  /// "SOP-HR-001 · v1.0" — whichever of the two the document actually carries.
  String get subtitle => [
    if ((code ?? '').isNotEmpty) code,
    if ((version ?? '').isNotEmpty) 'v$version',
  ].join(' · ');
}

/// A category chip on the employee social wall.
class SocialCategoryItem {
  final int id;
  final String name;
  final String icon;
  final String color;
  final String? description;

  SocialCategoryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.description,
  });

  factory SocialCategoryItem.fromJson(Map<String, dynamic> j) =>
      SocialCategoryItem(
        id: j['id'],
        name: j['name'] ?? '',
        icon: j['icon'] ?? 'sparkles',
        color: j['color'] ?? '#2F54C9',
        description: j['description'],
      );
}

/// One post on the social wall. `liked` and `likesCount` are mutable so the
/// like button can flip instantly and roll back if the request fails.
class SocialPostItem {
  final int id;
  final String body;
  final String? imageUrl;
  int likesCount;
  int commentsCount;
  bool liked;
  final bool isMine;
  final String author;
  final String? authorPhoto;
  final String? category;
  final String? categoryIcon;
  final String? categoryColor;
  final String? createdAt;
  final bool edited;

  /// Which category the post is filed under. `category` carries the name for
  /// display; this is the id the edit sheet needs to preselect the right chip.
  final int? categoryId;

  SocialPostItem({
    required this.id,
    required this.body,
    required this.likesCount,
    required this.commentsCount,
    required this.liked,
    required this.isMine,
    required this.author,
    this.imageUrl,
    this.authorPhoto,
    this.category,
    this.categoryIcon,
    this.categoryColor,
    this.createdAt,
    this.edited = false,
    this.categoryId,
  });

  factory SocialPostItem.fromJson(Map<String, dynamic> j) => SocialPostItem(
    id: j['id'],
    body: j['body'] ?? '',
    imageUrl: Env.resolveMedia(j['image_url'] as String?),
    likesCount: (j['likes_count'] as num?)?.toInt() ?? 0,
    commentsCount: (j['comments_count'] as num?)?.toInt() ?? 0,
    liked: j['liked'] == true,
    isMine: j['is_mine'] == true,
    author: j['author'] ?? 'Karyawan',
    authorPhoto: Env.resolveMedia(j['author_photo'] as String?),
    category: j['category'],
    categoryIcon: j['category_icon'],
    categoryColor: j['category_color'],
    createdAt: j['created_at'],
    edited: j['edited'] == true,
    categoryId: (j['social_category_id'] as num?)?.toInt(),
  );
}

/// A comment under a social post.
class SocialCommentItem {
  final int id;
  final String body;
  final String author;
  final String? authorPhoto;
  final bool isMine;
  final String? createdAt;

  /// Null on a top-level comment; the parent's id on a reply.
  final int? parentId;

  /// Whose comment this answers, set only when the indent cannot say — a reply
  /// to a reply sits beside the one it answers, not under it.
  final String? replyTo;

  /// Replies under this comment. Threads are one level deep, so a reply never
  /// carries replies of its own.
  final List<SocialCommentItem> replies;

  SocialCommentItem({
    required this.id,
    required this.body,
    required this.author,
    required this.isMine,
    this.authorPhoto,
    this.createdAt,
    this.parentId,
    this.replyTo,
    this.replies = const [],
  });

  factory SocialCommentItem.fromJson(Map<String, dynamic> j) =>
      SocialCommentItem(
        id: j['id'],
        body: j['body'] ?? '',
        author: j['author'] ?? 'Karyawan',
        authorPhoto: Env.resolveMedia(j['author_photo'] as String?),
        isMine: j['is_mine'] == true,
        createdAt: j['created_at'],
        parentId: (j['parent_id'] as num?)?.toInt(),
        replyTo: j['reply_to'] as String?,
        replies: ((j['replies'] as List?) ?? [])
            .map(
              (e) => SocialCommentItem.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(),
      );
}

/// One row of the idea-contributor leaderboard.
class SocialLeaderItem {
  final int rank;
  final int employeeId;
  final String name;
  final String? photo;
  final int posts;
  final int likes;
  final int comments;
  final int points;
  final bool isMe;

  SocialLeaderItem({
    required this.rank,
    required this.employeeId,
    required this.name,
    required this.posts,
    required this.likes,
    required this.comments,
    required this.points,
    required this.isMe,
    this.photo,
  });

  factory SocialLeaderItem.fromJson(Map<String, dynamic> j) => SocialLeaderItem(
    rank: (j['rank'] as num?)?.toInt() ?? 0,
    employeeId: (j['employee_id'] as num?)?.toInt() ?? 0,
    name: j['name'] ?? 'Karyawan',
    photo: Env.resolveMedia(j['photo'] as String?),
    posts: (j['posts'] as num?)?.toInt() ?? 0,
    likes: (j['likes'] as num?)?.toInt() ?? 0,
    comments: (j['comments'] as num?)?.toInt() ?? 0,
    points: (j['points'] as num?)?.toInt() ?? 0,
    isMe: j['is_me'] == true,
  );
}

/// One month of Employee of the Month voting.
class EotmPeriodItem {
  final int id;
  final String period;
  final String label;
  final String? title;
  final String? description;
  final String status;
  final bool isOpen;
  final String? winner;
  final int winnerVotes;
  final int totalVotes;

  EotmPeriodItem({
    required this.id,
    required this.period,
    required this.label,
    required this.status,
    required this.isOpen,
    required this.winnerVotes,
    required this.totalVotes,
    this.title,
    this.description,
    this.winner,
  });

  factory EotmPeriodItem.fromJson(Map<String, dynamic> j) => EotmPeriodItem(
    id: j['id'],
    period: j['period'] ?? '',
    label: j['label'] ?? '',
    title: j['title'],
    description: j['description'],
    status: j['status'] ?? 'draft',
    isOpen: j['is_open'] == true,
    winner: j['winner'],
    winnerVotes: (j['winner_votes'] as num?)?.toInt() ?? 0,
    totalVotes: (j['total_votes'] as num?)?.toInt() ?? 0,
  );
}

/// A core value a voter attributes to their nominee.
class EotmCoreValueItem {
  final int id;
  final String name;
  final String icon;
  final String color;

  EotmCoreValueItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  factory EotmCoreValueItem.fromJson(Map<String, dynamic> j) =>
      EotmCoreValueItem(
        id: j['id'],
        name: j['name'] ?? '',
        icon: j['icon'] ?? 'sparkles',
        color: j['color'] ?? '#7C3AED',
      );
}

/// One nominee's standing in the live tally.
class EotmStandingItem {
  final int rank;
  final int employeeId;
  final String name;
  final String? photo;
  final int votes;
  final int percent;
  final String? coreValue;
  final String? coreValueColor;

  EotmStandingItem({
    required this.rank,
    required this.employeeId,
    required this.name,
    required this.votes,
    required this.percent,
    this.photo,
    this.coreValue,
    this.coreValueColor,
  });

  factory EotmStandingItem.fromJson(Map<String, dynamic> j) => EotmStandingItem(
    rank: (j['rank'] as num?)?.toInt() ?? 0,
    employeeId: (j['employee_id'] as num?)?.toInt() ?? 0,
    name: j['name'] ?? 'Karyawan',
    photo: Env.resolveMedia(j['photo'] as String?),
    votes: (j['votes'] as num?)?.toInt() ?? 0,
    percent: (j['percent'] as num?)?.toInt() ?? 0,
    coreValue: j['core_value'],
    coreValueColor: j['core_value_color'],
  );
}

/// A colleague who can be voted for.
class EotmNomineeItem {
  final int id;
  final String name;
  final String? employeeNumber;
  final String? photo;

  EotmNomineeItem({
    required this.id,
    required this.name,
    this.employeeNumber,
    this.photo,
  });

  factory EotmNomineeItem.fromJson(Map<String, dynamic> j) => EotmNomineeItem(
    id: j['id'],
    name: j['name'] ?? 'Karyawan',
    employeeNumber: j['employee_number'],
    photo: Env.resolveMedia(j['photo'] as String?),
  );
}

/// The vote this employee already cast, if any.
class EotmMyVote {
  final int nomineeEmployeeId;
  final String? nominee;
  final int? coreValueId;
  final String? coreValue;
  final String? reason;

  EotmMyVote({
    required this.nomineeEmployeeId,
    this.nominee,
    this.coreValueId,
    this.coreValue,
    this.reason,
  });

  factory EotmMyVote.fromJson(Map<String, dynamic> j) => EotmMyVote(
    nomineeEmployeeId: (j['nominee_employee_id'] as num?)?.toInt() ?? 0,
    nominee: j['nominee'],
    coreValueId: (j['core_value_id'] as num?)?.toInt(),
    coreValue: j['core_value'],
    reason: j['reason'],
  );
}

/// Everything the voting screen needs, fetched in one call.
class EotmSnapshot {
  final EotmPeriodItem? period;
  final EotmMyVote? myVote;
  final List<EotmCoreValueItem> coreValues;
  final List<EotmStandingItem> standings;

  EotmSnapshot({
    required this.coreValues,
    required this.standings,
    this.period,
    this.myVote,
  });

  factory EotmSnapshot.fromJson(Map<String, dynamic> j) {
    final period = j['period'];
    final myVote = j['my_vote'];

    return EotmSnapshot(
      period: period == null
          ? null
          : EotmPeriodItem.fromJson(Map<String, dynamic>.from(period as Map)),
      myVote: myVote == null
          ? null
          : EotmMyVote.fromJson(Map<String, dynamic>.from(myVote as Map)),
      coreValues: ((j['core_values'] as List?) ?? [])
          .map((e) => EotmCoreValueItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      standings: ((j['standings'] as List?) ?? [])
          .map((e) => EotmStandingItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// One checklist task on a field visit, with its before/after evidence. The
/// before photo is captured when the report is filed; the after is added later
/// from the visit list once the work is done.
class VisitTask {
  final int id;
  final String title;
  final bool isDone;
  final String? photoNote;
  final String? beforeUrl;
  final String? afterUrl;

  VisitTask({
    required this.id,
    required this.title,
    required this.isDone,
    this.photoNote,
    this.beforeUrl,
    this.afterUrl,
  });

  bool get hasAfter => afterUrl != null && afterUrl!.isNotEmpty;

  factory VisitTask.fromJson(Map<String, dynamic> j) => VisitTask(
    id: j['id'],
    title: j['title'] ?? '',
    isDone: j['is_done'] ?? false,
    photoNote: j['photo_note'],
    beforeUrl: Env.resolveMedia(j['before_photo_url'] as String?),
    afterUrl: Env.resolveMedia(j['after_photo_url'] as String?),
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
  final List<VisitTask> tasks;

  FieldVisitItem({
    required this.id,
    required this.visitDate,
    required this.location,
    required this.status,
    this.clientName,
    this.purpose,
    this.notes,
    this.photoUrls = const [],
    this.tasks = const [],
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
    tasks: ((j['tasks'] as List?) ?? [])
        .map((e) => VisitTask.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
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
