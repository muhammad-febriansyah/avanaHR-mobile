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

/// A pack of AI tokens on sale.
class AiTokenPack {
  final int id;
  final String name;
  final int tokenAmount;
  final int price;
  final String? description;

  const AiTokenPack({
    required this.id,
    required this.name,
    required this.tokenAmount,
    required this.price,
    this.description,
  });

  factory AiTokenPack.fromJson(Map<String, dynamic> j) => AiTokenPack(
    id: (j['id'] as num?)?.toInt() ?? 0,
    name: j['name']?.toString() ?? '',
    tokenAmount: (j['token_amount'] as num?)?.toInt() ?? 0,
    price: (j['price'] as num?)?.toInt() ?? 0,
    description: j['description']?.toString(),
  );
}

/// What the signed-in person can spend, split by who paid for it.
///
/// The two are kept apart because "sisa 7.000" alone cannot say whether buying
/// more would help, or whether they are simply waiting for next month.
class AiTokenBalance {
  /// Left of the company's pools after this person's monthly cap. Null when the
  /// company sets no cap and has no quota — effectively unlimited.
  final int? companyRemaining;

  /// Tokens they bought themselves. Permanent, and outside the cap.
  final int personalBalance;

  /// The two added together.
  final int? effectiveRemaining;

  final int? userCap;
  final int userUsed;
  final String period;

  const AiTokenBalance({
    this.companyRemaining,
    required this.personalBalance,
    this.effectiveRemaining,
    this.userCap,
    required this.userUsed,
    required this.period,
  });

  factory AiTokenBalance.fromJson(Map<String, dynamic> j) => AiTokenBalance(
    companyRemaining: (j['company_remaining'] as num?)?.toInt(),
    personalBalance: (j['personal_balance'] as num?)?.toInt() ?? 0,
    effectiveRemaining: (j['effective_remaining'] as num?)?.toInt(),
    userCap: (j['user_cap'] as num?)?.toInt(),
    userUsed: (j['user_used'] as num?)?.toInt() ?? 0,
    period: j['period']?.toString() ?? '',
  );
}

/// One personal purchase, as listed in the history.
class AiTokenOrder {
  final String orderNumber;
  final String packName;
  final int tokenAmount;
  final int amount;
  final String status;

  const AiTokenOrder({
    required this.orderNumber,
    required this.packName,
    required this.tokenAmount,
    required this.amount,
    required this.status,
  });

  bool get isPaid => status == 'completed';

  factory AiTokenOrder.fromJson(Map<String, dynamic> j) => AiTokenOrder(
    orderNumber: j['order_number']?.toString() ?? '',
    packName: j['pack_name']?.toString() ?? '',
    tokenAmount: (j['token_amount'] as num?)?.toInt() ?? 0,
    amount: (j['amount'] as num?)?.toInt() ?? 0,
    status: j['status']?.toString() ?? 'pending',
  );
}
