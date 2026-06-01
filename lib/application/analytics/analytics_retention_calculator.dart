/// Cálculo puro de retenção D1/D7/D30 para testes e dashboard.
class AnalyticsRetentionCalculator {
  AnalyticsRetentionCalculator._();

  static RetentionResult compute({
    required Map<String, DateTime> signupsByUser,
    required Map<String, Set<String>> sessionsByUserDay,
    required DateTime now,
  }) {
    if (signupsByUser.isEmpty) {
      return const RetentionResult(
        d1: 0,
        d7: 0,
        d30: 0,
        cohortSize: 0,
      );
    }

    var retained1 = 0;
    var retained7 = 0;
    var retained30 = 0;
    var eligible1 = 0;
    var eligible7 = 0;
    var eligible30 = 0;

    for (final entry in signupsByUser.entries) {
      final uid = entry.key;
      final signup = entry.value;
      final daysSinceSignup = now.difference(signup).inDays;
      final userDays = sessionsByUserDay[uid] ?? {};

      if (daysSinceSignup >= 1) {
        eligible1++;
        if (_returnedOnDay(userDays, signup, 1)) retained1++;
      }
      if (daysSinceSignup >= 7) {
        eligible7++;
        if (_returnedOnDay(userDays, signup, 7)) retained7++;
      }
      if (daysSinceSignup >= 30) {
        eligible30++;
        if (_returnedOnDay(userDays, signup, 30)) retained30++;
      }
    }

    return RetentionResult(
      d1: eligible1 > 0 ? retained1 / eligible1 * 100 : 0,
      d7: eligible7 > 0 ? retained7 / eligible7 * 100 : 0,
      d30: eligible30 > 0 ? retained30 / eligible30 * 100 : 0,
      cohortSize: signupsByUser.length,
    );
  }

  static bool _returnedOnDay(
    Set<String> userDays,
    DateTime signup,
    int dayOffset,
  ) {
    final target = signup.add(Duration(days: dayOffset));
    return userDays.contains(dayKey(target));
  }

  static String dayKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

class RetentionResult {
  final double d1;
  final double d7;
  final double d30;
  final int cohortSize;

  const RetentionResult({
    required this.d1,
    required this.d7,
    required this.d30,
    required this.cohortSize,
  });
}
