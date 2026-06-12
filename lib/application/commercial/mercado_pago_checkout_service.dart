import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../../domain/platform/models/commercial_access_snapshot.dart';
import '../../services/app_check/app_check_service.dart';
import 'commercial_access_service.dart';

/// Região onde `createMercadoPagoCheckout` está deployada (Firebase Functions v2).
const kMercadoPagoFunctionsRegion = 'southamerica-east1';

/// Resultado do checkout Mercado Pago (Checkout Pro).
class MercadoPagoCheckoutResult {
  final String paymentId;
  final String preferenceId;
  final String checkoutUrl;
  final double amount;
  final String currency;
  final String billingPeriod;

  const MercadoPagoCheckoutResult({
    required this.paymentId,
    required this.preferenceId,
    required this.checkoutUrl,
    required this.amount,
    required this.currency,
    required this.billingPeriod,
  });

  factory MercadoPagoCheckoutResult.fromMap(Map<String, dynamic> data) {
    final checkoutUrl = MercadoPagoCheckoutService.resolveCheckoutUrl(data);
    return MercadoPagoCheckoutResult(
      paymentId: data['paymentId']?.toString() ?? '',
      preferenceId: data['preferenceId']?.toString() ?? '',
      checkoutUrl: checkoutUrl,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      currency: data['currency']?.toString() ?? 'BRL',
      billingPeriod: data['billingPeriod']?.toString() ?? 'monthly',
    );
  }
}

/// Diagnóstico de credenciais antes de callables sensíveis.
class CallableAuthDiagnostics {
  final bool hasUser;
  final String? uid;
  final String? email;
  final bool idTokenOk;
  final String? idTokenError;
  final bool appCheckReady;
  final bool appCheckTokenOk;
  final String? appCheckError;
  final String? appCheckProvider;

  const CallableAuthDiagnostics({
    required this.hasUser,
    this.uid,
    this.email,
    required this.idTokenOk,
    this.idTokenError,
    required this.appCheckReady,
    required this.appCheckTokenOk,
    this.appCheckError,
    this.appCheckProvider,
  });

  bool get readyForCheckout => hasUser && idTokenOk && appCheckReady && appCheckTokenOk;

  void log(String tag) {
    debugPrint(
      '$tag auth: hasUser=$hasUser uid=${uid ?? "null"} '
      'email=${email ?? "null"} idTokenOk=$idTokenOk '
      'appCheckReady=$appCheckReady appCheckOk=$appCheckTokenOk '
      'provider=${appCheckProvider ?? "n/a"}',
    );
    if (idTokenError != null) {
      debugPrint('$tag idTokenError: $idTokenError');
    }
    if (appCheckError != null) {
      debugPrint('$tag appCheckError: $appCheckError');
    }
  }
}

/// Integração Checkout Pro via Cloud Function `createMercadoPagoCheckout`.
class MercadoPagoCheckoutService {
  MercadoPagoCheckoutService({FirebaseFunctions? functions, FirebaseAuth? auth})
      : _functions = functions ?? _defaultFunctions(),
        _auth = auth ?? FirebaseAuth.instance;

  static FirebaseFunctions _defaultFunctions() {
    return FirebaseFunctions.instanceFor(
      app: Firebase.app(),
      region: kMercadoPagoFunctionsRegion,
    );
  }

  static const callableName = 'createMercadoPagoCheckout';
  static const reconcileCallableName = 'reconcileMyMercadoPagoPayments';

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  static final _callableOptions = HttpsCallableOptions(
    timeout: const Duration(seconds: 90),
  );

  /// Garante usuário autenticado (espera restauração da sessão no web).
  Future<User?> resolveCheckoutUser({Duration timeout = const Duration(seconds: 8)}) async {
    var user = _auth.currentUser;
    if (user != null) {
      try {
        await user.getIdToken(false);
      } catch (_) {}
      return user;
    }

    try {
      user = await _auth
          .authStateChanges()
          .firstWhere((u) => u != null)
          .timeout(timeout);
      return user;
    } catch (_) {
      return _auth.currentUser;
    }
  }

  /// Garante App Check pronto + ID token fresco antes da callable.
  Future<CallableAuthDiagnostics> _prepareCallableAuth({
    bool forceRefresh = true,
  }) async {
    final user = await resolveCheckoutUser();
    if (user == null) {
      const diag = CallableAuthDiagnostics(
        hasUser: false,
        idTokenOk: false,
        appCheckReady: false,
        appCheckTokenOk: false,
        appCheckError: 'currentUser == null',
      );
      diag.log('[MercadoPagoCheckout]');
      return diag;
    }

    String? idTokenError;
    var idTokenOk = false;
    try {
      final token = await user.getIdToken(forceRefresh);
      idTokenOk = token != null && token.isNotEmpty;
      if (!idTokenOk) {
        idTokenError = 'getIdToken retornou vazio';
      }
    } catch (e) {
      idTokenError = e.toString();
    }

    var appCheckReady = false;
    String? appCheckError;
    var appCheckTokenOk = false;
    String? provider = AppCheckService.instance.activeProviderLabel;

    try {
      await AppCheckService.instance.ensureReady();
      appCheckReady = AppCheckService.instance.isInitialized;
      provider = AppCheckService.instance.activeProviderLabel;

      // Em debug nativo, não forçar refresh a cada toque — reduz rate limit.
      final effectiveForceRefresh = forceRefresh && (kReleaseMode || kIsWeb);
      final tokenResult = await AppCheckService.instance.getTokenResult(
        forceRefresh: effectiveForceRefresh,
      );
      appCheckTokenOk = tokenResult.ok;
      if (!appCheckTokenOk) {
        appCheckError = tokenResult.userMessage;
        if (kDebugMode && tokenResult.failureKind != null) {
          debugPrint(
            '[MercadoPagoCheckout] App Check failureKind=${tokenResult.failureKind} '
            'retryAfter=${tokenResult.retryAfterSeconds ?? "n/a"}s',
          );
        }
      }
    } on AppCheckNotReadyException catch (e) {
      appCheckError = e.message;
    } catch (e) {
      appCheckError = e.toString();
    }

    final diag = CallableAuthDiagnostics(
      hasUser: true,
      uid: user.uid,
      email: user.email,
      idTokenOk: idTokenOk,
      idTokenError: idTokenError,
      appCheckReady: appCheckReady,
      appCheckTokenOk: appCheckTokenOk,
      appCheckError: appCheckError,
      appCheckProvider: provider,
    );
    diag.log('[MercadoPagoCheckout]');
    return diag;
  }

  static String resolveCheckoutUrl(Map<String, dynamic> data) {
    final direct = data['checkoutUrl']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final initPoint = data['init_point']?.toString().trim();
    if (initPoint != null && initPoint.isNotEmpty) return initPoint;

    final sandbox = data['sandbox_init_point']?.toString().trim();
    if (sandbox != null && sandbox.isNotEmpty) return sandbox;

    final metadata = data['metadata'];
    if (metadata is Map) {
      final metaUrl = metadata['checkoutUrl']?.toString().trim();
      if (metaUrl != null && metaUrl.isNotEmpty) return metaUrl;
    }

    return '';
  }

  static Map<String, dynamic> _coerceResponseMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw MercadoPagoCheckoutException(
      'Resposta inválida do servidor de pagamento.',
    );
  }

  Future<MercadoPagoCheckoutResult> createCheckout({
    required String planId,
    required String billingPeriod,
    String? couponCode,
    String? sellerId,
    String? affiliateId,
  }) async {
    return _invokeCreateCheckout(
      planId: planId,
      billingPeriod: billingPeriod,
      couponCode: couponCode,
      sellerId: sellerId,
      affiliateId: affiliateId,
      retryOnUnauthenticated: true,
    );
  }

  Future<MercadoPagoCheckoutResult> _invokeCreateCheckout({
    required String planId,
    required String billingPeriod,
    String? couponCode,
    String? sellerId,
    String? affiliateId,
    required bool retryOnUnauthenticated,
  }) async {
    debugPrint(
      '[MercadoPagoCheckout] createCheckout '
      'callable=$callableName region=$kMercadoPagoFunctionsRegion '
      'planId=$planId billing=$billingPeriod',
    );

    final diag = await _prepareCallableAuth(forceRefresh: true);
    if (!diag.readyForCheckout) {
      throw MercadoPagoCheckoutException.fromDiagnostics(diag);
    }

    final callable = _functions.httpsCallable(
      callableName,
      options: _callableOptions,
    );

    try {
      final response = await callable.call<Map<String, dynamic>>({
        'planId': planId,
        'billingPeriod': billingPeriod,
        if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
        if (sellerId != null && sellerId.isNotEmpty) 'sellerId': sellerId,
        if (affiliateId != null && affiliateId.isNotEmpty)
          'affiliateId': affiliateId,
      });

      final data = _coerceResponseMap(response.data);
      final result = MercadoPagoCheckoutResult.fromMap(data);

      debugPrint(
        '[MercadoPagoCheckout] OK paymentId=${result.paymentId} '
        'urlLen=${result.checkoutUrl.length}',
      );

      if (result.checkoutUrl.isEmpty) {
        throw MercadoPagoCheckoutException(
          'O servidor não retornou a URL do Mercado Pago. Tente novamente.',
        );
      }

      return result;
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '[MercadoPagoCheckout] FirebaseFunctionsException '
        '${e.code}: ${e.message} details=${e.details}',
      );

      final isGenericUnauth = e.code == 'unauthenticated' &&
          (e.message == null ||
              e.message!.isEmpty ||
              e.message == 'Unauthenticated');

      if (retryOnUnauthenticated && isGenericUnauth) {
        debugPrint(
          '[MercadoPagoCheckout] retry após refresh Auth (App Check sem forceRefresh em debug)',
        );
        await _prepareCallableAuth(forceRefresh: kReleaseMode || kIsWeb);
        return _invokeCreateCheckout(
          planId: planId,
          billingPeriod: billingPeriod,
          couponCode: couponCode,
          sellerId: sellerId,
          affiliateId: affiliateId,
          retryOnUnauthenticated: false,
        );
      }

      throw MercadoPagoCheckoutException.fromFunctions(e, diag);
    } catch (e) {
      if (e is MercadoPagoCheckoutException) rethrow;
      debugPrint('[MercadoPagoCheckout] error: $e');
      throw MercadoPagoCheckoutException(
        'Não foi possível iniciar o pagamento. Verifique sua conexão e tente de novo.',
      );
    }
  }

  Future<void> openCheckoutUrl(String checkoutUrl) async {
    final trimmed = checkoutUrl.trim();
    if (trimmed.isEmpty) {
      throw MercadoPagoCheckoutException(
        'URL de pagamento vazia. Não foi possível abrir o Mercado Pago.',
      );
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      throw MercadoPagoCheckoutException('URL de pagamento inválida.');
    }

    debugPrint('[MercadoPagoCheckout] open ${uri.host} web=$kIsWeb');

    var launched = false;
    if (kIsWeb) {
      launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
    } else {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    }

    if (!launched) {
      throw MercadoPagoCheckoutException(
        'Não foi possível abrir o Mercado Pago. '
        'Tente novamente ou use outro navegador.',
      );
    }
  }

  Future<MercadoPagoCheckoutResult> startCheckout({
    required String planId,
    required String billingPeriod,
    String? couponCode,
    String? sellerId,
    String? affiliateId,
  }) async {
    final result = await createCheckout(
      planId: planId,
      billingPeriod: billingPeriod,
      couponCode: couponCode,
      sellerId: sellerId,
      affiliateId: affiliateId,
    );
    await openCheckoutUrl(result.checkoutUrl);
    return result;
  }

  Future<ReconcilePaymentsResult> reconcileMyPayments() async {
    final diag = await _prepareCallableAuth(forceRefresh: false);
    if (!diag.readyForCheckout) {
      throw MercadoPagoCheckoutException.fromDiagnostics(diag);
    }

    final callable = _functions.httpsCallable(
      reconcileCallableName,
      options: _callableOptions,
    );
    final response = await callable.call<Map<String, dynamic>>();
    final data = _coerceResponseMap(response.data);
    final ids = (data['paymentIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    return ReconcilePaymentsResult(
      reconciled: (data['reconciled'] as num?)?.toInt() ?? 0,
      paymentIds: ids,
    );
  }

  /// Reconcilia pagamentos pendentes e aguarda [CommercialAccessSnapshot.hasPremiumAccess]
  /// refletir no Firestore (web pós-checkout). Não concede Premium no cliente.
  Future<PremiumConfirmationResult> reconcileAndWaitForPremium({
    required String userId,
    required CommercialAccessService commercialAccess,
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(milliseconds: 1200),
    Duration secondReconcileAfter = const Duration(seconds: 3),
  }) async {
    ReconcilePaymentsResult? lastReconcile;

    Future<void> tryReconcile() async {
      try {
        lastReconcile = await reconcileMyPayments();
      } catch (e, st) {
        debugPrint(
          '[MercadoPagoCheckout] reconcileAndWaitForPremium reconcile: $e\n$st',
        );
      }
    }

    await tryReconcile();
    unawaited(
      Future<void>.delayed(secondReconcileAfter, tryReconcile),
    );

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final snap = await commercialAccess.getAccess(userId);
      if (snap.hasPremiumAccess) {
        return PremiumConfirmationResult(
          premiumActive: true,
          timedOut: false,
          lastReconcile: lastReconcile,
        );
      }
      await Future.delayed(pollInterval);
    }

    await tryReconcile();
    final finalSnap = await commercialAccess.getAccess(userId);
    return PremiumConfirmationResult(
      premiumActive: finalSnap.hasPremiumAccess,
      timedOut: !finalSnap.hasPremiumAccess,
      lastReconcile: lastReconcile,
    );
  }
}

class ReconcilePaymentsResult {
  final int reconciled;
  final List<String> paymentIds;

  const ReconcilePaymentsResult({
    required this.reconciled,
    required this.paymentIds,
  });
}

/// Resultado de [MercadoPagoCheckoutService.reconcileAndWaitForPremium].
class PremiumConfirmationResult {
  const PremiumConfirmationResult({
    required this.premiumActive,
    required this.timedOut,
    this.lastReconcile,
  });

  final bool premiumActive;
  final bool timedOut;
  final ReconcilePaymentsResult? lastReconcile;
}

enum MercadoPagoCheckoutFailureKind {
  notSignedIn,
  sessionExpired,
  appCheck,
  callable,
  invalidCoupon,
  other,
}

class MercadoPagoCheckoutException implements Exception {
  MercadoPagoCheckoutException(this.message, {this.kind = MercadoPagoCheckoutFailureKind.other});

  final String message;
  final MercadoPagoCheckoutFailureKind kind;

  @override
  String toString() => message;

  factory MercadoPagoCheckoutException.fromDiagnostics(CallableAuthDiagnostics diag) {
    if (!diag.hasUser) {
      return MercadoPagoCheckoutException(
        'Faça login para assinar o Premium.',
        kind: MercadoPagoCheckoutFailureKind.notSignedIn,
      );
    }
    if (!diag.idTokenOk) {
      return MercadoPagoCheckoutException(
        'Sua sessão expirou. Saia da conta, entre de novo e tente o pagamento.',
        kind: MercadoPagoCheckoutFailureKind.sessionExpired,
      );
    }
    if (!diag.appCheckReady || !diag.appCheckTokenOk) {
      final detail = diag.appCheckError ?? AppCheckService.instance.lastError;
      final msg = detail != null && detail.isNotEmpty
          ? (detail.startsWith('Verificação App Check') ||
                  detail.startsWith('App Check')
              ? detail
              : 'Verificação App Check indisponível: $detail')
          : 'Verificação App Check indisponível. '
              'No site, confira RECAPTCHA_V3_SITE_KEY e o debug token Web no Firebase Console.';
      return MercadoPagoCheckoutException(
        msg,
        kind: MercadoPagoCheckoutFailureKind.appCheck,
      );
    }
    return MercadoPagoCheckoutException(
      'Não foi possível iniciar o pagamento. Tente novamente.',
      kind: MercadoPagoCheckoutFailureKind.other,
    );
  }

  factory MercadoPagoCheckoutException.fromFunctions(
    FirebaseFunctionsException e,
    CallableAuthDiagnostics diag,
  ) {
    final msg = e.message ?? '';
    final lower = msg.toLowerCase();

    if (_isCouponError(e.code, msg)) {
      return MercadoPagoCheckoutException(
        msg.isNotEmpty ? msg : 'Cupom inválido ou indisponível.',
        kind: MercadoPagoCheckoutFailureKind.invalidCoupon,
      );
    }

    switch (e.code) {
      case 'unauthenticated':
        if (!diag.hasUser) {
          return MercadoPagoCheckoutException(
            'Faça login para assinar o Premium.',
            kind: MercadoPagoCheckoutFailureKind.notSignedIn,
          );
        }
        if (!diag.appCheckTokenOk) {
          return MercadoPagoCheckoutException.fromDiagnostics(diag);
        }
        if (!diag.idTokenOk) {
          return MercadoPagoCheckoutException(
            'Sua sessão expirou. Saia da conta, entre de novo e tente o pagamento.',
            kind: MercadoPagoCheckoutFailureKind.sessionExpired,
          );
        }
        if (msg.isNotEmpty && msg != 'Unauthenticated') {
          return MercadoPagoCheckoutException(
            msg,
            kind: MercadoPagoCheckoutFailureKind.callable,
          );
        }
        return MercadoPagoCheckoutException(
          'O servidor recusou a requisição. Se você já está logado, '
          'verifique App Check Web (console F12 → logs [AppCheck]).',
          kind: MercadoPagoCheckoutFailureKind.appCheck,
        );
      case 'app-check':
        return MercadoPagoCheckoutException.fromDiagnostics(diag);
      case 'permission-denied':
      case 'failed-precondition':
        if (lower.contains('app check')) {
          return MercadoPagoCheckoutException.fromDiagnostics(diag);
        }
        if (msg.contains('MERCADOPAGO') ||
            msg.contains('webhook') ||
            msg.contains('ACCESS_TOKEN')) {
          return MercadoPagoCheckoutException(
            'Pagamento temporariamente indisponível. Tente mais tarde.',
            kind: MercadoPagoCheckoutFailureKind.callable,
          );
        }
        if (msg.contains('preço') || msg.contains('preço configurado')) {
          return MercadoPagoCheckoutException(
            'Plano sem preço configurado no Painel Mestre.',
            kind: MercadoPagoCheckoutFailureKind.callable,
          );
        }
        return MercadoPagoCheckoutException(
          msg.isNotEmpty ? msg : 'Não foi possível iniciar o checkout.',
          kind: MercadoPagoCheckoutFailureKind.callable,
        );
      case 'not-found':
        return MercadoPagoCheckoutException(
          msg.isNotEmpty ? msg : 'Plano não encontrado. Atualize a tela e tente novamente.',
          kind: MercadoPagoCheckoutFailureKind.callable,
        );
      case 'resource-exhausted':
        return MercadoPagoCheckoutException(
          'Muitas tentativas. Aguarde alguns minutos.',
          kind: MercadoPagoCheckoutFailureKind.callable,
        );
      case 'unavailable':
        return MercadoPagoCheckoutException(
          'Serviço indisponível. Tente em instantes.',
          kind: MercadoPagoCheckoutFailureKind.callable,
        );
      default:
        return MercadoPagoCheckoutException(
          msg.isNotEmpty ? msg : 'Erro ao iniciar pagamento (${e.code}).',
          kind: MercadoPagoCheckoutFailureKind.callable,
        );
    }
  }

  static bool _isCouponError(String code, String message) {
    final lower = message.toLowerCase();
    if (lower.contains('cupom')) return true;
    return code == 'not-found' && lower.contains('cupom');
  }
}
