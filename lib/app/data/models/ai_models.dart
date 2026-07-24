// Models for the AI Assistant feature. Mirrors the JSON returned by the
// `/me/ai*` mobile endpoints. Every payload is scoped to the caller — the
// assistant only ever reads the signed-in employee's own data.

/// Monthly AI token allowance vs. consumption for the caller's tenant.
class AiTokenUsage {
  final int used;
  final int? quota;
  final String period;

  const AiTokenUsage({required this.used, this.quota, required this.period});

  factory AiTokenUsage.fromJson(Map<String, dynamic> j) => AiTokenUsage(
    used: (j['used'] as num?)?.toInt() ?? 0,
    quota: (j['quota'] as num?)?.toInt(),
    period: j['period']?.toString() ?? '',
  );

  bool get hasQuota => quota != null && quota! > 0;

  /// Consumed share of the quota, clamped to [0, 1].
  double get fraction =>
      hasQuota ? (used / quota!).clamp(0.0, 1.0).toDouble() : 0.0;

  int get remaining => hasQuota ? (quota! - used).clamp(0, quota!) : 0;
}

/// A single chat turn.
class AiChatMessage {
  final int? id;
  final String role; // 'user' | 'assistant'
  final String content;

  const AiChatMessage({this.id, required this.role, required this.content});

  bool get isUser => role == 'user';

  factory AiChatMessage.fromJson(Map<String, dynamic> j) => AiChatMessage(
    id: (j['id'] as num?)?.toInt(),
    role: j['role']?.toString() ?? 'assistant',
    content: j['content']?.toString() ?? '',
  );
}

/// A row in the conversation history list.
class AiConversationSummary {
  final int id;
  final String title;
  final String? updatedAt;

  const AiConversationSummary({
    required this.id,
    required this.title,
    this.updatedAt,
  });

  factory AiConversationSummary.fromJson(Map<String, dynamic> j) =>
      AiConversationSummary(
        id: (j['id'] as num).toInt(),
        title: j['title']?.toString() ?? 'Percakapan',
        updatedAt: j['updated_at']?.toString(),
      );
}

/// The assistant landing payload: readiness, token meter, history, prompts.
class AiSession {
  final bool ready;
  final AiTokenUsage usage;
  final List<AiConversationSummary> conversations;
  final List<String> suggestions;

  const AiSession({
    required this.ready,
    required this.usage,
    required this.conversations,
    required this.suggestions,
  });

  factory AiSession.fromJson(Map<String, dynamic> j) => AiSession(
    ready: j['ready'] == true,
    usage: AiTokenUsage.fromJson(
      Map<String, dynamic>.from(j['usage'] as Map? ?? const {}),
    ),
    conversations: ((j['conversations'] as List?) ?? const [])
        .map(
          (e) => AiConversationSummary.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList(),
    suggestions: ((j['suggestions'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
  );
}
