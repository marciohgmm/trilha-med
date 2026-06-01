import 'package:flutter/material.dart';

/// Navigator raiz — usado por FCM para deep links.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Messenger raiz do [MaterialApp] — usado por diálogos (reporte/suporte)
/// para SnackBars mesmo quando o [context] do overlay não encontra scaffold.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
