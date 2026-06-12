/// Contadores de uso P0 (`users/{uid}/access_usage/stats`).
class AccessUsageStats {
  const AccessUsageStats({
    this.flashcardsConsumed = 0,
    this.questionsConsumed = 0,
  });

  final int flashcardsConsumed;
  final int questionsConsumed;

  factory AccessUsageStats.fromMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return const AccessUsageStats();
    return AccessUsageStats(
      flashcardsConsumed: _readInt(data['flashcardsConsumed']),
      questionsConsumed: _readInt(data['questionsConsumed']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'flashcardsConsumed': flashcardsConsumed,
      'questionsConsumed': questionsConsumed,
    };
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}

/// Motivo de bloqueio ou bypass em [ContentAccessService].
enum ContentAccessBlockReason {
  none,
  enforcementOff,
  premiumBypass,
  adminBypass,
  featureDisabled,
  limitReached,
}

/// Resultado de tentativa de consumo de cota.
class ConsumeResult {
  const ConsumeResult({
    required this.allowed,
    required this.newlyConsumed,
    required this.reason,
    this.limit,
    this.used,
  });

  final bool allowed;
  final bool newlyConsumed;
  final ContentAccessBlockReason reason;
  final int? limit;
  final int? used;

  int? get remaining {
    if (limit == null || used == null) return null;
    final r = limit! - used!;
    return r < 0 ? 0 : r;
  }

  factory ConsumeResult.allowed({
    bool newlyConsumed = false,
    ContentAccessBlockReason reason = ContentAccessBlockReason.none,
    int? limit,
    int? used,
  }) {
    return ConsumeResult(
      allowed: true,
      newlyConsumed: newlyConsumed,
      reason: reason,
      limit: limit,
      used: used,
    );
  }

  factory ConsumeResult.blocked({
    required ContentAccessBlockReason reason,
    int? limit,
    int? used,
  }) {
    return ConsumeResult(
      allowed: false,
      newlyConsumed: false,
      reason: reason,
      limit: limit,
      used: used,
    );
  }
}
