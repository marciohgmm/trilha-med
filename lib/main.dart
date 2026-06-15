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

  FlutterError.onError = (FlutterErrorDetails details) {
    _bootLog('FlutterError: ${details.exceptionAsString()}', error: true);
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  };

  await runZonedGuarded(
    () async {
      await _bootstrapAndRunApp();
    },
    (Object error, StackTrace stack) {
      _bootLog('Exceção não capturada: $error', error: true);
      if (kDebugMode) {
        _bootLog('$stack', error: true);
      }
    },
  );
}

Future<void> _bootstrapAndRunApp() async {
  _bootLog('Iniciando bootstrap…');

  await _bootStep(
    'Firebase.initializeApp',
    () => Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ),
  );

  final appCheckReady = await _bootStep(
    'AppCheck.activate',
    () => AppCheckService.instance.initialize(),
  );
  if (appCheckReady != true) {
    final detail = AppCheckService.instance.lastError;
    _bootLog(
      'App Check não ficou pronto no boot (app abre mesmo assim). '
      '${detail ?? "sem detalhe"}',
      error: true,
    );
  }

  _bootStepSync('Firestore offline cache', configureFirestoreForOffline);

  await _bootStep(
    'Analytics.initialize',
    () => AppAnalyticsService.instance.initialize(),
  );

  await _bootStep(
    'FCM.initialize',
    () => FcmService.instance.initialize(navigatorKey: rootNavigatorKey),
  );

  await _bootStep(
    'StudyTimer.loadSettings',
    () => StudyTimerService().loadSettings(),
  );

  await _bootStep(
    'SystemChrome',
    () async {
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
    },
  );

  runApp(const TrilhaMedApp());
  _bootLog('runApp(TrilhaMedApp) — UI iniciada');

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_deferredBootWork());
  });
}

Future<void> _deferredBootWork() async {
  _bootLog('Serviços adiados (pós-primeiro-frame)…');

  await _bootStep(
    'AppCheck.warmUpToken',
    () => AppCheckService.instance.warmUpTokenInBackground(),
  );

  unawaited(_refreshBootCachesSafely());
}

void _bootLog(String message, {bool error = false}) {
  final prefix = error ? '[BOOT][ERRO]' : '[BOOT]';
  debugPrint('$prefix $message');
}

Future<T?> _bootStep<T>(String name, Future<T> Function() action) async {
  _bootLog('$name — iniciando');
  try {
    final result = await action();
    _bootLog('$name — OK');
    return result;
  } catch (e, st) {
    _bootLog('$name — falhou: $e', error: true);
    if (kDebugMode) {
      _bootLog('$st', error: true);
    }
    return null;
  }
}

void _bootStepSync(String name, void Function() action) {
  _bootLog('$name — iniciando');
  try {
    action();
    _bootLog('$name — OK');
  } catch (e, st) {
    _bootLog('$name — falhou: $e', error: true);
    if (kDebugMode) {
      _bootLog('$st', error: true);
    }
  }
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
    _bootLog('$tag.refreshCache — OK');
  } catch (e) {
    _bootLog('$tag.refreshCache — falhou: $e', error: true);
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
            backgroundColor: Colors.white,
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
              child: child ??
                  const ColoredBox(
                    color: Colors.white,
                    child: Center(child: CircularProgressIndicator()),
                  ),
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
