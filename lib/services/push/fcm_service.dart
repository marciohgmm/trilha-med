import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'push_navigation_handler.dart';

/// Handler de mensagens em background (top-level obrigatório).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background: ${message.messageId}');
}

/// Firebase Cloud Messaging + notificações locais em foreground.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _currentUserId;
  GlobalKey<NavigatorState>? _navigatorKey;

  static const _androidChannel = AndroidNotificationChannel(
    'trilhamed_default',
    'Trilha Med',
    description: 'Notificações gerais do app',
    importance: Importance.high,
  );

  Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_initialized) return;
    _navigatorKey = navigatorKey;

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }

    await _requestPermission();

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _pendingOpenData = initial.data;
    }

    _messaging.onTokenRefresh.listen((token) {
      final uid = _currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && token.isNotEmpty) {
        registerToken(userId: uid, token: token);
      }
    });

    _initialized = true;
  }

  Map<String, dynamic>? _pendingOpenData;

  Future<void> bindUser(String userId) async {
    _currentUserId = userId;
    if (kIsWeb) return;

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await registerToken(userId: userId, token: token);
    }

    if (_pendingOpenData != null) {
      final data = _pendingOpenData!;
      _pendingOpenData = null;
      _handleOpen(data);
    }
  }

  Future<void> unbindUser() async {
    _currentUserId = null;
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');
  }

  Future<void> registerToken({
    required String userId,
    required String token,
  }) async {
    if (kIsWeb) return;
    try {
      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'other';
      final callable = FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      ).httpsCallable('registerFcmToken');
      await callable.call<Map<String, dynamic>>({
        'token': token,
        'platform': platform,
      });
    } catch (e) {
      debugPrint('registerFcmToken error: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _local.show(
      message.hashCode,
      notification.title ?? 'Trilha Med',
      notification.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['type'],
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    _handleOpen(message.data);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    // Payload local é só o type; abrir home.
    final type = response.payload;
    if (type != null) {
      _handleOpen({'type': type});
    }
  }

  void _handleOpen(Map<String, dynamic> data) {
    final uid = _currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
    final nav = _navigatorKey?.currentState;
    if (uid == null || nav == null) {
      _pendingOpenData = data;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navigatorKey?.currentContext;
      if (ctx == null || !ctx.mounted) return;
      PushNavigationHandler.handle(ctx, userId: uid, data: data);
    });
  }

  /// Tópicos opcionais para broadcast (complementar à segmentação server-side).
  Future<void> subscribePromotional(bool subscribe) async {
    if (kIsWeb) return;
    const topic = 'promotional';
    if (subscribe) {
      await _messaging.subscribeToTopic(topic);
    } else {
      await _messaging.unsubscribeFromTopic(topic);
    }
  }

  Future<void> syncPromotionalTopic(bool enabled) async {
    await subscribePromotional(enabled);
  }
}
