import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;

import 'app_scaffold.dart';
import 'firebase_options.dart';
import 'services/app_check/app_check_service.dart';
import 'services/feature_flags/feature_flag_service.dart';
import 'services/analytics/app_analytics_service.dart';
import 'services/push/fcm_service.dart';
import 'services/firestore_init.dart';
import 'services/study_timer_service.dart';
import 'screens/login_page.dart';
import 'screens/main_navigation_page.dart';
import 'widgets/legal/legal_acceptance_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await AppCheckService.instance.initialize();

  unawaited(FeatureFlagService.instance.refreshCache());

  // Firestore: cache em disco + modo offline (ver [configureFirestoreForOffline]).
  configureFirestoreForOffline();

  await AppAnalyticsService.instance.initialize();

  await FcmService.instance.initialize(navigatorKey: rootNavigatorKey);

  await StudyTimerService().loadSettings();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  runApp(const TrilhaMedApp());
}

/// Observa o estado de autenticação e abre login ou a área logada do app.
class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return const LoginPage();
        }
        if (!user.emailVerified) {
          return const LoginPage();
        }
        return LegalAcceptanceGate(
          userId: user.uid,
          child: MainNavigationPage(userId: user.uid),
        );
      },
    );
  }
}

class TrilhaMedApp extends StatelessWidget {
  const TrilhaMedApp({super.key});

  static ThemeData _theme(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E3A8A),
        brightness: brightness,
      ),
      useMaterial3: true,
      brightness: brightness,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appearance = StudyTimerService();

    return ListenableBuilder(
      listenable: appearance,
      builder: (context, _) {
        final scale = appearance.textScaleFactor;

        return MaterialApp(
          title: 'Trilha Med',
          debugShowCheckedModeBanner: false,
          navigatorKey: rootNavigatorKey,
          navigatorObservers: [
            AppAnalyticsService.instance.observer,
          ],
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [
            Locale('pt', 'BR'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          themeMode: ThemeMode.light,
          theme: _theme(Brightness.light),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const AuthCheck(),
        );
      },
    );
  }
}

/// Widget de debug legado — **não** usar em [runApp]. Mantido para rollback local.
/// MIGRADO: antes exibia `Image.asset('assets/images/Imagenscard/...')` para teste.
class UpdateApp extends StatelessWidget {
  const UpdateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      home: Scaffold(
        appBar: AppBar(
          title: const Text('UpdateApp (legado — não usar)'),
        ),
        body: const Center(
          child: Text(
            'Este modo de teste foi desativado. Use TrilhaMedApp em main.dart.\n'
            'Imagens de flashcard: Firebase Storage (imagenscard/).',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
