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

/// One deep analysis the web already paid for — read-only on the phone.
class MeetingInsight {
  final String type;
  final String label;
  final Map<String, dynamic> payload;
  final DateTime? generatedAt;

  const MeetingInsight({
    required this.type,
    required this.label,
    this.payload = const {},
    this.generatedAt,
  });

  factory MeetingInsight.fromJson(Map<String, dynamic> j) => MeetingInsight(
    type: j['type']?.toString() ?? '',
    label: j['label']?.toString() ?? '',
    payload: Map<String, dynamic>.from((j['payload'] as Map?) ?? {}),
    generatedAt: DateTime.tryParse(
      j['generated_at']?.toString() ?? '',
    )?.toLocal(),
  );

  /// The analysis boiled down to lines a phone can show without a bespoke
  /// layout per type. Each analysis has its own shape, but all of them read as
  /// a short list of points, so that is what is rendered.
  List<String> get bullets => switch (type) {
    'executive_summary' => [
      if (_string('headline').isNotEmpty) _string('headline'),
      ..._strings('key_points'),
    ],
    'decision_analysis' => _maps(
      'decisions',
    ).map((d) => _join([d['decision'], d['rationale']], ' — ')).toList(),
    'project_risk' => _maps('risks')
        .map(
          (r) => _join([
            r['risk'],
            if (r['severity'] != null) 'risiko ${r['severity']}',
            r['mitigation'],
          ], ' · '),
        )
        .toList(),
    'sentiment' => [
      if (_string('overall').isNotEmpty) 'Sentimen: ${_string('overall')}',
      if (_string('note').isNotEmpty) _string('note'),
      ..._strings('tension_points'),
    ],
    'follow_up' => _maps('recommendations')
        .map(
          (r) => _join([
            r['action'],
            r['owner'],
            r['deadline'],
          ], ' · '),
        )
        .toList(),
    _ => const [],
  };

  String _string(String key) => payload[key]?.toString() ?? '';

  List<String> _strings(String key) => ((payload[key] as List?) ?? [])
      .map((e) => e.toString())
      .where((e) => e.isNotEmpty)
      .toList();

  List<Map<String, dynamic>> _maps(String key) => ((payload[key] as List?) ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  String _join(List<Object?> parts, String separator) => parts
      .map((p) => p?.toString().trim() ?? '')
      .where((p) => p.isNotEmpty)
      .join(separator);
}

/// A meeting opened up: everything the list carries, plus what was said.
class MeetingDetail {
  final MeetingItem meeting;
  final String? summary;

  /// Decisions as the server stored them. Not carved back out of the summary
  /// prose — that contract used to be a literal heading, and a model that
  /// worded it differently dropped them silently.
  final List<String> decisions;

  final String? failureReason;
  final List<MeetingLine> transcript;
  final List<MeetingActionItem> actionItems;
  final List<MeetingInsight> insights;

  const MeetingDetail({
    required this.meeting,
    this.summary,
    this.decisions = const [],
    this.failureReason,
    this.transcript = const [],
    this.actionItems = const [],
    this.insights = const [],
  });

  factory MeetingDetail.fromJson(Map<String, dynamic> j) => MeetingDetail(
    meeting: MeetingItem.fromJson(j),
    summary: j['summary']?.toString(),
    decisions: ((j['decisions'] as List?) ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList(),
    failureReason: j['failure_reason']?.toString(),
    transcript: ((j['transcript'] as List?) ?? [])
        .map((e) => MeetingLine.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    actionItems: ((j['action_items'] as List?) ?? [])
        .map((e) => MeetingActionItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    insights: ((j['insights'] as List?) ?? [])
        .map((e) => MeetingInsight.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );

  bool get hasSummaryContent =>
      (summary ?? '').trim().isNotEmpty || decisions.isNotEmpty;
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
