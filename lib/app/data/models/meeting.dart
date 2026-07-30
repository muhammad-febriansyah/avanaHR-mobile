// Models for the AI Recorder (Rapat & Transkrip). Mirrors the JSON returned by
// the `/me/meetings*` endpoints. A meeting is readable only by the person who
// recorded it, the people listed as attending, or the whole company when it was
// opened up — the server decides, these are just the shapes.

/// Whether the recorder may run at all, and what a minute of it costs.
class MeetingRecorderStatus {
  /// A speech provider is configured platform-wide.
  final bool available;

  /// ...and this caller still has tokens to spend on it.
  final bool canRecord;

  final String? blockedMessage;

  /// Hard ceiling per recording, enforced server-side too.
  final int? maxMinutes;

  final int? tokenCostPerMinute;

  /// Whether the server keeps the audio file after transcribing.
  final bool keepAudio;

  const MeetingRecorderStatus({
    required this.available,
    required this.canRecord,
    this.blockedMessage,
    this.maxMinutes,
    this.tokenCostPerMinute,
    this.keepAudio = false,
  });

  factory MeetingRecorderStatus.fromJson(Map<String, dynamic> j) =>
      MeetingRecorderStatus(
        available: j['available'] == true,
        canRecord: j['can_record'] == true,
        blockedMessage: j['blocked_message']?.toString(),
        maxMinutes: (j['max_minutes'] as num?)?.toInt(),
        tokenCostPerMinute: (j['token_cost_per_minute'] as num?)?.toInt(),
        keepAudio: j['keep_audio'] == true,
      );

  static const unavailable = MeetingRecorderStatus(
    available: false,
    canRecord: false,
  );
}

/// The short-lived credential and socket parameters for one recording session.
///
/// The provider's project key never reaches the phone — this token expires
/// within a minute and is re-minted as needed.
class MeetingSttGrant {
  final String accessToken;
  final int expiresIn;
  final String wsUrl;
  final Map<String, String> params;
  final int maxMinutes;

  /// How much audio the server bills in one go, so the phone can pace its
  /// heartbeat to match.
  final int blockMs;

  const MeetingSttGrant({
    required this.accessToken,
    required this.expiresIn,
    required this.wsUrl,
    required this.params,
    required this.maxMinutes,
    required this.blockMs,
  });

  factory MeetingSttGrant.fromJson(Map<String, dynamic> j) => MeetingSttGrant(
    accessToken: j['access_token']?.toString() ?? '',
    expiresIn: (j['expires_in'] as num?)?.toInt() ?? 60,
    wsUrl: j['ws_url']?.toString() ?? '',
    params: ((j['params'] as Map?) ?? {}).map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    ),
    maxMinutes: (j['max_minutes'] as num?)?.toInt() ?? 180,
    blockMs: (j['block_ms'] as num?)?.toInt() ?? 15000,
  );

  /// The listening socket, with the model and language the server chose.
  Uri get uri => Uri.parse(wsUrl).replace(queryParameters: params);
}

/// One recorded meeting as the list shows it.
class MeetingItem {
  final int id;
  final String title;
  final String? location;

  /// `recording` | `processing` | `ready` | `failed`
  final String status;

  final DateTime? startedAt;
  final int durationMs;
  final int durationMinutes;
  final bool hasSummary;
  final List<String> participants;

  const MeetingItem({
    required this.id,
    required this.title,
    this.location,
    required this.status,
    this.startedAt,
    this.durationMs = 0,
    this.durationMinutes = 0,
    this.hasSummary = false,
    this.participants = const [],
  });

  factory MeetingItem.fromJson(Map<String, dynamic> j) => MeetingItem(
    id: (j['id'] as num).toInt(),
    title: j['title']?.toString() ?? 'Rapat',
    location: j['location']?.toString(),
    status: j['status']?.toString() ?? 'ready',
    startedAt: DateTime.tryParse(j['started_at']?.toString() ?? '')?.toLocal(),
    durationMs: (j['duration_ms'] as num?)?.toInt() ?? 0,
    durationMinutes: (j['duration_minutes'] as num?)?.toInt() ?? 0,
    hasSummary: j['has_summary'] == true,
    participants: ((j['participants'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
  );

  bool get isReady => status == 'ready';
  bool get isFailed => status == 'failed';

  /// Still being transcribed or summarised — nothing to read yet.
  bool get isWorking => status == 'recording' || status == 'processing';

  String get statusLabel => switch (status) {
    'recording' => 'Merekam',
    'processing' => 'Diproses',
    'failed' => 'Gagal',
    _ => 'Siap',
  };
}

/// One line of transcript: who said it, when, and what.
class MeetingLine {
  final String timecode;
  final int startMs;
  final String speaker;
  final String text;

  const MeetingLine({
    required this.timecode,
    required this.startMs,
    required this.speaker,
    required this.text,
  });

  factory MeetingLine.fromJson(Map<String, dynamic> j) => MeetingLine(
    timecode: j['timecode']?.toString() ?? '00:00',
    startMs: (j['start_ms'] as num?)?.toInt() ?? 0,
    speaker: j['speaker']?.toString() ?? 'Pembicara',
    text: j['text']?.toString() ?? '',
  );
}

/// A follow-up the meeting produced.
class MeetingActionItem {
  final int id;
  final String text;
  final String? assignee;
  final String? dueDate;
  final String status;

  const MeetingActionItem({
    required this.id,
    required this.text,
    this.assignee,
    this.dueDate,
    required this.status,
  });

  factory MeetingActionItem.fromJson(Map<String, dynamic> j) =>
      MeetingActionItem(
        id: (j['id'] as num).toInt(),
        text: j['text']?.toString() ?? '',
        assignee: j['assignee']?.toString(),
        dueDate: j['due_date']?.toString(),
        status: j['status']?.toString() ?? 'open',
      );

  bool get isDone => status == 'done';
}

/// A meeting opened up: everything the list carries, plus what was said.
class MeetingDetail {
  final MeetingItem meeting;
  final String? summary;
  final String? failureReason;
  final List<MeetingLine> transcript;
  final List<MeetingActionItem> actionItems;

  const MeetingDetail({
    required this.meeting,
    this.summary,
    this.failureReason,
    this.transcript = const [],
    this.actionItems = const [],
  });

  factory MeetingDetail.fromJson(Map<String, dynamic> j) => MeetingDetail(
    meeting: MeetingItem.fromJson(j),
    summary: j['summary']?.toString(),
    failureReason: j['failure_reason']?.toString(),
    transcript: ((j['transcript'] as List?) ?? [])
        .map((e) => MeetingLine.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    actionItems: ((j['action_items'] as List?) ?? [])
        .map((e) => MeetingActionItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );

  /// The summary split into the prose and the "## Keputusan" bullets the
  /// server appends, so each can be styled on its own.
  ({String body, List<String> decisions}) get parsedSummary {
    final raw = (summary ?? '').trim();
    if (raw.isEmpty) return (body: '', decisions: const []);

    final marker = raw.indexOf('## Keputusan');
    if (marker < 0) return (body: raw, decisions: const []);

    final decisions = raw
        .substring(marker)
        .split('\n')
        .where((l) => l.trimLeft().startsWith('-'))
        .map((l) => l.trimLeft().substring(1).trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return (body: raw.substring(0, marker).trim(), decisions: decisions);
  }
}

/// One finalised utterance the phone is holding to send on the next heartbeat.
class PendingSegment {
  final int startMs;
  final int endMs;
  final int speaker;
  final String text;

  const PendingSegment({
    required this.startMs,
    required this.endMs,
    required this.speaker,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
    'start_ms': startMs,
    'end_ms': endMs,
    'speaker': speaker,
    'text': text,
  };
}
