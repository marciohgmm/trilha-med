import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';



import '../../application/commercial/commercial_access_service.dart';

import '../../application/platform/platform_registry.dart';

import '../../core/commercial/commercial_entitlement.dart';

import '../../domain/platform/models/commercial_access_snapshot.dart';

import '../../screens/commercial/plans_page.dart';

import '../../services/analytics/app_analytics_service.dart';



/// Protege conteúdo por entitlement — opt-in; não altera telas legadas até ser aplicado.

class PaywallGate extends StatefulWidget {

  const PaywallGate({

    super.key,

    required this.requiredEntitlement,

    required this.child,

    this.fallback,

    this.userId,

    this.showUpgradePrompt = true,

    this.screenName,

  });



  final CommercialEntitlementKey requiredEntitlement;

  final Widget child;

  final Widget? fallback;

  final String? userId;

  final bool showUpgradePrompt;

  final String? screenName;



  @override

  State<PaywallGate> createState() => _PaywallGateState();

}



class _PaywallGateState extends State<PaywallGate> {

  bool _paywallLogged = false;



  void _logPaywallView(String uid) {

    if (_paywallLogged) return;

    _paywallLogged = true;

    AppAnalyticsService.instance.logPaywallView(

      userId: uid,

      entitlement: widget.requiredEntitlement.key,

      screenName: widget.screenName,

    );

  }



  @override

  Widget build(BuildContext context) {

    final uid = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {

      return widget.fallback ?? _lockedView(context, signedOut: true);

    }



    final service = PlatformRegistry.instance.commercialAccess;

    return StreamBuilder<CommercialAccessSnapshot>(

      stream: service.watchAccess(uid),

      builder: (context, snap) {

        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {

          return const Center(child: CircularProgressIndicator());

        }

        final access = snap.data ?? CommercialAccessSnapshot.free(uid);

        if (access.hasKey(widget.requiredEntitlement) ||

            (widget.requiredEntitlement == CommercialEntitlementKey.premium &&

                access.hasPremiumAccess)) {

          return widget.child;

        }

        _logPaywallView(uid);

        return widget.fallback ?? _lockedView(context, signedOut: false);

      },

    );

  }



  Widget _lockedView(BuildContext context, {required bool signedOut}) {

    return Center(

      child: Padding(

        padding: const EdgeInsets.all(24),

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Icon(

              Icons.lock_outline,

              size: 56,

              color: Colors.grey.shade400,

            ),

            const SizedBox(height: 16),

            Text(

              signedOut ? 'Faça login para continuar' : 'Recurso Premium',

              style: const TextStyle(

                fontSize: 20,

                fontWeight: FontWeight.bold,

                color: Color(0xFF1E3A8A),

              ),

              textAlign: TextAlign.center,

            ),

            const SizedBox(height: 8),

            Text(

              signedOut

                  ? 'Entre na sua conta para acessar este conteúdo.'

                  : 'Este recurso requer ${widget.requiredEntitlement.label}.',

              textAlign: TextAlign.center,

              style: TextStyle(color: Colors.grey.shade700),

            ),

            if (widget.showUpgradePrompt && !signedOut) ...[

              const SizedBox(height: 20),

              FilledButton.icon(

                onPressed: () => Navigator.of(context).push(

                  MaterialPageRoute(builder: (_) => const PlansPage()),

                ),

                icon: const Icon(Icons.workspace_premium),

                label: const Text('Ver planos'),

                style: FilledButton.styleFrom(

                  backgroundColor: const Color(0xFF1E3A8A),

                ),

              ),

            ],

          ],

        ),

      ),

    );

  }

}



/// Atalho estático para verificar acesso sem widget.

class PaywallGuard {

  PaywallGuard._();



  static CommercialAccessService get _service =>

      PlatformRegistry.instance.commercialAccess;



  static Stream<bool> watchHasEntitlement(

    String userId,

    CommercialEntitlementKey key,

  ) {

    return _service.watchAccess(userId).map((snap) {

      if (key == CommercialEntitlementKey.premium) {

        return snap.hasPremiumAccess;

      }

      return snap.hasKey(key);

    });

  }



  static Future<bool> hasEntitlement(

    String userId,

    CommercialEntitlementKey key,

  ) async {

    final snap = await _service.getAccess(userId);

    if (key == CommercialEntitlementKey.premium) return snap.hasPremiumAccess;

    return snap.hasKey(key);

  }

}


