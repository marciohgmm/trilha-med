import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/constants/firestore_paths.dart';
import '../../firebase_options.dart';
import '../../services/auth/admin_auth_service.dart';
import 'master_admin_diagnostics_models.dart';

/// Diagnóstico automático Firestore — somente Painel Mestre (administradores).
class MasterAdminDiagnosticsService {
  MasterAdminDiagnosticsService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  static const expectedProjectId = 'revalida-cards';

  Future<MasterAdminDiagnosticReport> run() async {
    final user = _auth.currentUser;
    final identity = await _loadIdentity(user);
    final probes = await _runProbes(identity);
    final projectId = Firebase.app().options.projectId;
    final environment = _buildEnvironmentFindings(
      identity: identity,
      probes: probes,
      projectId: projectId,
    );

    return MasterAdminDiagnosticReport(
      identity: identity,
      firebaseProjectId: projectId,
      expectedProjectId: expectedProjectId,
      probes: probes,
      environmentFindings: environment,
      generatedAt: DateTime.now(),
    );
  }

  static bool isPermissionDenied(Object? error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }
    final text = error.toString().toLowerCase();
    return text.contains('permission-denied') ||
        text.contains('missing or insufficient permissions');
  }

  Future<MasterAdminIdentitySnapshot> _loadIdentity(User? user) async {
    if (user == null) {
      return const MasterAdminIdentitySnapshot();
    }

    final founder = AdminAuthService.isFounderUser(user);
    var usersDocExists = false;
    var usersIsAdmin = false;
    var rbacRoles = <String>[];

    try {
      final userSnap =
          await _db.collection(FirestorePaths.users).doc(user.uid).get();
      usersDocExists = userSnap.exists;
      final data = userSnap.data();
      usersIsAdmin = data?['isAdmin'] == true;
      rbacRoles = _readStringList(data?['rbacRoles']);
    } catch (_) {}

    var adminsDocExists = false;
    try {
      final adminSnap =
          await _db.collection(FirestorePaths.admins).doc(user.uid).get();
      adminsDocExists = adminSnap.exists;
    } catch (_) {}

    final isAppAdmin = founder || adminsDocExists || usersIsAdmin;

    return MasterAdminIdentitySnapshot(
      isAuthenticated: true,
      uid: user.uid,
      email: user.email ?? '',
      emailVerified: user.emailVerified,
      isFounder: founder,
      usersDocExists: usersDocExists,
      usersIsAdmin: usersIsAdmin,
      rbacRoles: rbacRoles,
      adminsDocExists: adminsDocExists,
      isAppAdminEffective: isAppAdmin,
    );
  }

  Future<List<MasterAdminProbeResult>> _runProbes(
    MasterAdminIdentitySnapshot identity,
  ) async {
    if (!identity.isAuthenticated) {
      return [
        MasterAdminProbeResult.fail(
          collection: '(auth)',
          operation: 'FirebaseAuth.currentUser',
          errorCode: 'unauthenticated',
          errorMessage: 'Nenhum usuário autenticado',
          probableCause: 'Sessão Firebase Auth ausente ou expirada',
          suggestion:
              'Faça login novamente. O Painel Mestre exige usuário autenticado.',
        ),
      ];
    }

    return [
      await _probeQuery(
        collection: FirestorePaths.platformSellers,
        operation: 'limit(1).get()',
        run: () => _db
            .collection(FirestorePaths.platformSellers)
            .limit(1)
            .get(),
        identity: identity,
        readRequiresAdmin: false,
      ),
      await _probeQuery(
        collection: FirestorePaths.platformAffiliates,
        operation: 'limit(1).get()',
        run: () => _db
            .collection(FirestorePaths.platformAffiliates)
            .limit(1)
            .get(),
        identity: identity,
        readRequiresAdmin: false,
      ),
      await _probeQuery(
        collection: FirestorePaths.platformSubscriptionPlans,
        operation: "where(isActive==true).limit(1).get()",
        run: () => _db
            .collection(FirestorePaths.platformSubscriptionPlans)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get(),
        identity: identity,
        readRequiresAdmin: false,
      ),
      await _probeQuery(
        collection: FirestorePaths.platformAuditLogs,
        operation: 'orderBy(createdAt desc).limit(1).get()',
        run: () => _db
            .collection(FirestorePaths.platformAuditLogs)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get(),
        identity: identity,
        readRequiresAdmin: true,
      ),
    ];
  }

  Future<MasterAdminProbeResult> _probeQuery({
    required String collection,
    required String operation,
    required Future<void> Function() run,
    required MasterAdminIdentitySnapshot identity,
    required bool readRequiresAdmin,
  }) async {
    try {
      await run();
      return MasterAdminProbeResult.ok(
        collection: collection,
        operation: operation,
      );
    } on FirebaseException catch (e) {
      return MasterAdminProbeResult.fail(
        collection: collection,
        operation: operation,
        errorCode: e.code,
        errorMessage: e.message ?? e.toString(),
        probableCause: _probableCauseForProbe(
          code: e.code,
          collection: collection,
          identity: identity,
          readRequiresAdmin: readRequiresAdmin,
        ),
        suggestion: _suggestionForProbe(
          code: e.code,
          collection: collection,
          identity: identity,
          readRequiresAdmin: readRequiresAdmin,
        ),
      );
    } catch (e) {
      return MasterAdminProbeResult.fail(
        collection: collection,
        operation: operation,
        errorCode: 'unknown',
        errorMessage: e.toString(),
        probableCause: 'Erro inesperado ao consultar $collection',
        suggestion: 'Verifique conexão, índices Firestore e logs do dispositivo.',
      );
    }
  }

  String _probableCauseForProbe({
    required String code,
    required String collection,
    required MasterAdminIdentitySnapshot identity,
    required bool readRequiresAdmin,
  }) {
    if (code == 'permission-denied') {
      if (!identity.isAuthenticated) {
        return 'Requisição Firestore sem autenticação válida';
      }
      if (!readRequiresAdmin) {
        return 'Rules da coleção $collection provavelmente não publicadas '
            '(default deny) ou projeto Firebase incorreto';
      }
      if (!identity.isAppAdminEffective) {
        return 'Conta autenticada não satisfaz isAppAdmin() — '
            'faltam founder, admins/{uid} ou users.isAdmin';
      }
      return 'Regra Firestore de $collection negou a operação '
            '(ver firestore.rules)';
    }
    if (code == 'failed-precondition') {
      return 'Índice composto ausente para a query em $collection';
    }
    if (code == 'not-found') {
      return 'Documento ou coleção referenciada não encontrada';
    }
    return 'Falha ao acessar $collection ($code)';
  }

  String _suggestionForProbe({
    required String code,
    required String collection,
    required MasterAdminIdentitySnapshot identity,
    required bool readRequiresAdmin,
  }) {
    if (code == 'permission-denied') {
      if (!readRequiresAdmin) {
        return 'Execute firebase deploy --only firestore:rules no projeto '
            '$expectedProjectId. Confirme projectId do app '
            '(${DefaultFirebaseOptions.currentPlatform.projectId}).';
      }
      if (!identity.adminsDocExists && !identity.usersIsAdmin && !identity.isFounder) {
        return 'Conceda admin: crie admins/${identity.uid} ou defina '
            'users/${identity.uid}.isAdmin = true (grantAdmin no app).';
      }
      return 'Revise firestore.rules para $collection e confirme deploy.';
    }
    if (code == 'failed-precondition') {
      return 'Publique firestore.indexes.json (firebase deploy --only firestore:indexes).';
    }
    return 'Consulte docs/MASTER_ADMIN_CRITICAL_AUDIT.md e o Request Monitor '
        'no Firebase Console.';
  }

  List<MasterAdminEnvironmentFinding> _buildEnvironmentFindings({
    required MasterAdminIdentitySnapshot identity,
    required List<MasterAdminProbeResult> probes,
    required String projectId,
  }) {
    final findings = <MasterAdminEnvironmentFinding>[];

    if (projectId != expectedProjectId) {
      findings.add(
        MasterAdminEnvironmentFinding(
          title: 'Projeto Firebase incorreto',
          detail: 'App conectado a "$projectId"; esperado "$expectedProjectId".',
          suggestion: 'Verifique firebase_options.dart e google-services.json.',
        ),
      );
    }

    if (!identity.isAuthenticated) {
      findings.add(
        const MasterAdminEnvironmentFinding(
          title: 'Usuário não autenticado',
          detail: 'Firebase Auth não retornou currentUser.',
          suggestion: 'Faça login e reabra o Painel Mestre.',
        ),
      );
      return findings;
    }

    final catalogProbes = probes.where((p) {
      return p.collection == FirestorePaths.platformSellers ||
          p.collection == FirestorePaths.platformAffiliates;
    });
    final catalogDenied = catalogProbes.every(
      (p) => !p.success && p.isPermissionDenied,
    );
    if (catalogDenied && catalogProbes.isNotEmpty) {
      findings.add(
        const MasterAdminEnvironmentFinding(
          title: 'Rules não publicadas (provável)',
          detail: 'platform_sellers e platform_affiliates negam leitura mesmo '
              'para usuário autenticado — típico quando o bloco platform_* '
              'não está no Firestore em produção.',
          suggestion: 'firebase deploy --only firestore:rules',
        ),
      );
    }

    if (!identity.adminsDocExists &&
        !identity.usersIsAdmin &&
        !identity.isFounder) {
      findings.add(
        MasterAdminEnvironmentFinding(
          title: 'Usuário sem admins/{uid} e sem users.isAdmin',
          detail: 'UID ${identity.uid} — isAppAdmin() no Firestore tende a false.',
          suggestion: 'Use grantAdmin ou crie admins/${identity.uid} manualmente.',
        ),
      );
    } else if (!identity.adminsDocExists && identity.usersIsAdmin) {
      findings.add(
        const MasterAdminEnvironmentFinding(
          title: 'Usuário sem admins/{uid} (somente flag isAdmin)',
          detail: 'isAppAdmin() pode ser true, mas admins.count() no Dashboard '
              'usa isAdmin() (exige doc em admins/ ou founder).',
          suggestion: 'Crie admins/{uid} para alinhar métricas do Dashboard.',
        ),
      );
    }

    if (identity.rbacRoles.isNotEmpty && !identity.isAppAdminEffective) {
      findings.add(
        MasterAdminEnvironmentFinding(
          title: 'Divergência RBAC × Firestore',
          detail: 'rbacRoles=${identity.rbacRoles.join(", ")} no cliente, '
              'mas isAppAdmin() efetivo=false no Firestore.',
          suggestion: 'RBAC libera UI; Firestore exige admins/ ou users.isAdmin.',
        ),
      );
    }

    final auditProbe = probes.where(
      (p) => p.collection == FirestorePaths.platformAuditLogs,
    );
    if (auditProbe.isNotEmpty &&
        auditProbe.first.isPermissionDenied &&
        catalogProbes.any((p) => p.success)) {
      findings.add(
        const MasterAdminEnvironmentFinding(
          title: 'Privilégios Firestore insuficientes',
          detail: 'Catálogo platform_* legível, mas platform_audit_logs negado — '
              'conta não é isAppAdmin().',
          suggestion: 'Conceda admin via admins/{uid} ou users.isAdmin.',
        ),
      );
    }

    return findings;
  }

  List<String> _readStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }
}
