/// Resultado de uma sonda Firestore do diagnóstico do Painel Mestre.
class MasterAdminProbeResult {
  final String collection;
  final String operation;
  final bool success;
  final String? errorCode;
  final String? errorMessage;
  final String probableCause;
  final String suggestion;

  const MasterAdminProbeResult({
    required this.collection,
    required this.operation,
    required this.success,
    this.errorCode,
    this.errorMessage,
    this.probableCause = '',
    this.suggestion = '',
  });

  factory MasterAdminProbeResult.ok({
    required String collection,
    required String operation,
  }) {
    return MasterAdminProbeResult(
      collection: collection,
      operation: operation,
      success: true,
    );
  }

  factory MasterAdminProbeResult.fail({
    required String collection,
    required String operation,
    required String errorCode,
    required String errorMessage,
    required String probableCause,
    required String suggestion,
  }) {
    return MasterAdminProbeResult(
      collection: collection,
      operation: operation,
      success: false,
      errorCode: errorCode,
      errorMessage: errorMessage,
      probableCause: probableCause,
      suggestion: suggestion,
    );
  }

  bool get isPermissionDenied =>
      errorCode == 'permission-denied' ||
      (errorMessage?.toLowerCase().contains('permission-denied') ?? false);
}

/// Identidade e sinais admin do usuário logado.
class MasterAdminIdentitySnapshot {
  final bool isAuthenticated;
  final String uid;
  final String email;
  final bool emailVerified;
  final bool isFounder;
  final bool usersDocExists;
  final bool usersIsAdmin;
  final List<String> rbacRoles;
  final bool adminsDocExists;
  final bool isAppAdminEffective;

  const MasterAdminIdentitySnapshot({
    this.isAuthenticated = false,
    this.uid = '',
    this.email = '',
    this.emailVerified = false,
    this.isFounder = false,
    this.usersDocExists = false,
    this.usersIsAdmin = false,
    this.rbacRoles = const [],
    this.adminsDocExists = false,
    this.isAppAdminEffective = false,
  });
}

/// Achado da seção "Diagnóstico do Ambiente".
class MasterAdminEnvironmentFinding {
  final String title;
  final String detail;
  final String suggestion;

  const MasterAdminEnvironmentFinding({
    required this.title,
    required this.detail,
    required this.suggestion,
  });
}

/// Relatório completo gerado ao abrir o Painel Mestre.
class MasterAdminDiagnosticReport {
  final MasterAdminIdentitySnapshot identity;
  final String firebaseProjectId;
  final String expectedProjectId;
  final List<MasterAdminProbeResult> probes;
  final List<MasterAdminEnvironmentFinding> environmentFindings;
  final DateTime generatedAt;

  const MasterAdminDiagnosticReport({
    required this.identity,
    required this.firebaseProjectId,
    required this.expectedProjectId,
    required this.probes,
    required this.environmentFindings,
    required this.generatedAt,
  });

  bool get hasPermissionDeniedProbes =>
      probes.any((p) => !p.success && p.isPermissionDenied);

  bool get hasIssues =>
      hasPermissionDeniedProbes || environmentFindings.isNotEmpty;

  bool get shouldShowPanel => hasIssues;
}
