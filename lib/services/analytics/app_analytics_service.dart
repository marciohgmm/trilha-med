import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';



import '../../core/analytics/analytics_daily_record.dart';

import '../../core/analytics/analytics_events.dart';

import '../../core/analytics/analytics_mirror_policy.dart';

import '../../core/constants/firestore_paths.dart';



/// Firebase Analytics (GA4) + espelho Firestore seletivo para dashboard admin.

class AppAnalyticsService {

  AppAnalyticsService._();

  static final AppAnalyticsService instance = AppAnalyticsService._();



  FirebaseAnalytics? _analytics;

  FirebaseFirestore? _firestore;



  static const _lastSessionKey = 'analytics_last_session_day';

  static const _rawRetentionDays = 90;



  FirebaseAnalytics get analytics => _analytics ??= FirebaseAnalytics.instance;



  FirebaseAnalyticsObserver get observer =>

      FirebaseAnalyticsObserver(analytics: analytics);



  Future<void> initialize() async {

    _analytics ??= FirebaseAnalytics.instance;

    _firestore ??= FirebaseFirestore.instance;

    await analytics.setAnalyticsCollectionEnabled(!kDebugMode);

  }



  Future<void> setUserId(String? userId) async {

    await analytics.setUserId(id: userId);

  }



  Future<void> setUserProperty(String name, String? value) async {

    if (value == null || value.isEmpty) return;

    await analytics.setUserProperty(name: name, value: value);

  }



  Future<void> logSessionStart({required String userId}) async {

    final prefs = await SharedPreferences.getInstance();

    final today = analyticsDayKey(DateTime.now());

    if (prefs.getString(_lastSessionKey) == today) return;

    await prefs.setString(_lastSessionKey, today);



    await logEvent(

      AnalyticsEvents.sessionStart,

      userId: userId,

      parameters: {'day': today},

    );

    await _touchUserActivity(userId);

  }



  Future<void> logLogin({required String userId, String method = 'email'}) async {

    await setUserId(userId);

    await analytics.logLogin(loginMethod: method);

    await logEvent(

      AnalyticsEvents.login,

      userId: userId,

      parameters: {AnalyticsParams.method: method},

    );

  }



  Future<void> logSignUp({required String userId, String method = 'email'}) async {

    await setUserId(userId);

    await analytics.logSignUp(signUpMethod: method);

    await logEvent(

      AnalyticsEvents.signUp,

      userId: userId,

      parameters: {AnalyticsParams.method: method},

    );

    await _markSignup(userId);

  }



  Future<void> logScreenView(String screenName, {String? userId}) async {

    await analytics.logScreenView(screenName: screenName);

    await logEvent(

      AnalyticsEvents.screenView,

      userId: userId,

      parameters: {AnalyticsParams.screenName: screenName},

    );

  }



  Future<void> logFeatureEvent(

    String eventName, {

    String? userId,

    Map<String, Object?> parameters = const {},

  }) =>

      logEvent(eventName, userId: userId, parameters: parameters);



  Future<void> logPaywallView({

    required String userId,

    required String entitlement,

    String? screenName,

  }) =>

      logEvent(

        AnalyticsEvents.paywallView,

        userId: userId,

        parameters: {

          AnalyticsParams.entitlement: entitlement,

          if (screenName != null) AnalyticsParams.screenName: screenName,

        },

      );



  Future<void> logCheckoutStart({

    required String userId,

    required String planId,

    required String billingPeriod,

    required double amount,

    String? couponCode,

    String? sellerId,

    String? affiliateId,

    String? paymentId,

  }) async {

    await logEvent(

      AnalyticsEvents.checkoutStart,

      userId: userId,

      parameters: {

        AnalyticsParams.planId: planId,

        AnalyticsParams.billingPeriod: billingPeriod,

        AnalyticsParams.amount: amount,

        AnalyticsParams.currency: 'BRL',

        if (paymentId != null) AnalyticsParams.paymentId: paymentId,

        if (couponCode != null && couponCode.isNotEmpty)

          AnalyticsParams.couponCode: couponCode.toUpperCase(),

        if (sellerId != null) AnalyticsParams.sellerId: sellerId,

        if (affiliateId != null) AnalyticsParams.affiliateId: affiliateId,

      },

    );

    if (couponCode != null && couponCode.isNotEmpty) {

      await logEvent(

        AnalyticsEvents.couponApplied,

        userId: userId,

        parameters: {AnalyticsParams.couponCode: couponCode.toUpperCase()},

      );

    }

    if (affiliateId != null && affiliateId.isNotEmpty) {

      await logEvent(

        AnalyticsEvents.affiliateAttributed,

        userId: userId,

        parameters: {AnalyticsParams.affiliateId: affiliateId},

      );

    }

    if (sellerId != null && sellerId.isNotEmpty) {

      await logEvent(

        AnalyticsEvents.sellerAttributed,

        userId: userId,

        parameters: {AnalyticsParams.sellerId: sellerId},

      );

    }

  }



  Future<void> logPurchaseApproved({

    required String userId,

    required String planId,

    required double amount,

    String? paymentId,

    String? billingPeriod,

  }) async {

    await analytics.logPurchase(

      currency: 'BRL',

      value: amount,

      parameters: {

        AnalyticsParams.planId: planId,

        if (paymentId != null) AnalyticsParams.paymentId: paymentId,

        if (billingPeriod != null) AnalyticsParams.billingPeriod: billingPeriod,

      },

    );

    await logEvent(

      AnalyticsEvents.purchaseApproved,

      userId: userId,

      parameters: {

        AnalyticsParams.planId: planId,

        AnalyticsParams.amount: amount,

        AnalyticsParams.currency: 'BRL',

        if (paymentId != null) AnalyticsParams.paymentId: paymentId,

        if (billingPeriod != null) AnalyticsParams.billingPeriod: billingPeriod,

      },

    );

  }



  Future<void> logPurchaseCancelled({

    required String userId,

    String? planId,

    String? paymentId,

  }) =>

      logEvent(

        AnalyticsEvents.purchaseCancelled,

        userId: userId,

        parameters: {

          if (planId != null) AnalyticsParams.planId: planId,

          if (paymentId != null) AnalyticsParams.paymentId: paymentId,

        },

      );



  Future<void> logPurchasePending({

    required String userId,

    String? paymentId,

  }) =>

      logEvent(

        AnalyticsEvents.purchasePending,

        userId: userId,

        parameters: {

          if (paymentId != null) AnalyticsParams.paymentId: paymentId,

        },

      );



  /// GA4 sempre; espelho Firestore apenas para [AnalyticsMirrorPolicy].

  Future<void> logEvent(

    String name, {

    String? userId,

    Map<String, Object?> parameters = const {},

    bool? mirror,

  }) async {

    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;

    final sanitized = _sanitizeParams(parameters);

    final shouldMirror =

        mirror ?? AnalyticsMirrorPolicy.shouldMirrorToFirestore(name);



    try {

      await analytics.logEvent(name: name, parameters: sanitized);

    } catch (e) {

      debugPrint('Analytics FA error: $e');

    }



    if (shouldMirror && uid != null) {

      await _mirrorToFirestore(name, uid, sanitized);

    }

  }



  Map<String, Object> _sanitizeParams(Map<String, Object?> raw) {

    final out = <String, Object>{};

    for (final e in raw.entries) {

      final v = e.value;

      if (v == null) continue;

      if (v is String || v is num) {

        out[e.key] = v;

      } else {

        out[e.key] = v.toString();

      }

    }

    return out;

  }



  Future<void> _mirrorToFirestore(

    String name,

    String userId,

    Map<String, Object> parameters,

  ) async {

    try {

      final db = _firestore ?? FirebaseFirestore.instance;

      final now = DateTime.now();

      final dayKey = analyticsDayKey(now);

      final expireAt = Timestamp.fromDate(

        now.add(const Duration(days: _rawRetentionDays)),

      );



      final batch = db.batch();



      final eventRef =

          db.collection(FirestorePaths.platformAnalyticsEvents).doc();

      batch.set(eventRef, {

        'eventName': name,

        'userId': userId,

        'parameters': parameters,

        'createdAt': FieldValue.serverTimestamp(),

        'expireAt': expireAt,

      });



      final dailyRef =

          db.collection(FirestorePaths.platformAnalyticsDaily).doc(dayKey);

      // Contadores diários no doc raiz: apenas Functions (Admin SDK).
      // Cliente grava eventos brutos + presença em active_users (rules).

      if (name == AnalyticsEvents.sessionStart) {

        batch.set(

          dailyRef.collection('active_users').doc(userId),

          {'at': FieldValue.serverTimestamp()},

          SetOptions(merge: true),

        );

      }



      await batch.commit();

    } catch (e) {

      debugPrint('Analytics Firestore mirror error: $e');

    }

  }



  Future<void> _touchUserActivity(String userId) async {

    try {

      final db = _firestore ?? FirebaseFirestore.instance;

      await db.collection(FirestorePaths.users).doc(userId).set({

        'lastActiveAt': FieldValue.serverTimestamp(),

        'updatedAt': FieldValue.serverTimestamp(),

      }, SetOptions(merge: true));

    } catch (_) {}

  }



  Future<void> _markSignup(String userId) async {

    try {

      final db = _firestore ?? FirebaseFirestore.instance;

      await db.collection(FirestorePaths.users).doc(userId).set({

        'signupTrackedAt': FieldValue.serverTimestamp(),

        'createdAt': FieldValue.serverTimestamp(),

      }, SetOptions(merge: true));

    } catch (_) {}

  }

}


