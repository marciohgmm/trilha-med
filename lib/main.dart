import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;

import 'app_scaffold.dart';
import 'firebase_options.dart';
import 'services/app_check/app_check_service.dart';
import 'services/access/app_access_config_service.dart';
import 'services/feature_flags/feature_flag_service.dart';
import 'services/analytics/app_analytics_service.dart';
import 'services/push/fcm_service.dart';
import 'services/firestore_init.dart';
import 'services/study_timer_service.dart';
import 'screens/commercial/checkout_return_page.dart';
import 'screens/login_page.dart';
import 'screens/main_navigation_page.dart';
import 'utils/checkout_route_parser.dart';
import 'widgets/legal/legal_acceptance_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check no boot: falha não impede abrir o app (evita tela preta no APK).
  // Checkout/callables continuam exigindo App Check via MercadoPagoCheckoutService.
  final appCheckReady = await AppCheckService.instance.initialize();
  if (!appCheckReady) {
    final detail = AppCheckService.instance.lastError;
    debugPrint(
      '[main] App Check não ficou pronto no arranque. '
      'O app abre normalmente; pagamento e callables protegidas podem falhar. '
      '${detail != null ? "Detalhe: $detail. " : ""}'
      'Release: configure Play Integrity + SHA no Firebase Console.',
    );
  }

  unawaited(_refreshBootCachesSafely());

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

Future<void> _refreshBootCachesSafely() async {
  await _refreshBootCache('FeatureFlag', FeatureFlagService.instance.refreshCache);
  await _refreshBootCache('AppAccessConfig', AppAccessConfigService.instance.refreshCache);
}

Future<void> _refreshBootCache(
  String tag,
  Future<void> Function() refresh,
) async {
  try {
    await refresh();
  } catch (e) {
    if (!kDebugMode) return;
    final lower = e.toString().toLowerCase();
    final network = lower.contains('eai_nodata') ||
        lower.contains('getaddrinfo') ||
        lower.contains('unable to resolve host') ||
        lower.contains('network') ||
        lower.contains('permission-denied');
    debugPrint('[$tag] refreshCache no boot falhou: $e');
    if (network) {
      debugPrint(
        '[$tag] provável REDE/DNS ou App Check ainda sem token — '
        'Firestore pode negar até internet/DNS e debug secret estarem OK',
      );
    }
  }
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
          initialRoute: CheckoutRouteParser.resolveInitialRoute(),
          onGenerateRoute: _onGenerateRoute,
        );
      },
    );
  }
}

Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
  final checkoutArgs = CheckoutRouteParser.tryParseRouteSettings(settings.name);
  if (checkoutArgs != null) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => CheckoutReturnPage.fromRouteArgs(checkoutArgs),
    );
  }

  final name = settings.name ?? '/';
  if (name == '/' || name.isEmpty) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const AuthCheck(),
    );
  }

  if (kDebugMode) {
    debugPrint('[TrilhaMedApp] rota desconhecida "$name" — fallback AuthCheck');
  }
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => const AuthCheck(),
  );
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
