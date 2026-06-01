import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/study_pause_messages.dart';

/// Timer de estudo + preferências de aparência (tema / tamanho da fonte).
class StudyTimerService extends ChangeNotifier {
  static final StudyTimerService _instance = StudyTimerService._internal();
  factory StudyTimerService() => _instance;
  StudyTimerService._internal();

  Timer? _studyTimer;
  Timer? _pauseTimer;
  Duration _studyTime = Duration.zero;
  Duration _pauseTime = Duration.zero;
  bool _isStudying = false;
  bool _isPaused = false;
  bool _alertShown = false;

  // Configurações
  Duration _studyDuration = const Duration(minutes: 50);
  Duration _pauseDuration = const Duration(minutes: 10);
  bool _enableSound = true;
  bool _showFloatingClock = true;
  bool _enablePauseReminder = true;
  int _themeModeIndex = 0; // legado; app usa sempre tema claro
  int _fontSize = 16;
  bool _floatingClockDismissed = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final Random _random = Random();

  // Streams para notificar mudanças
  final StreamController<Duration> _studyTimeController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _pauseTimeController =
      StreamController<Duration>.broadcast();
  final StreamController<String> _alertController =
      StreamController<String>.broadcast();

  Stream<Duration> get studyTimeStream => _studyTimeController.stream;
  Stream<Duration> get pauseTimeStream => _pauseTimeController.stream;
  Stream<String> get alertStream => _alertController.stream;

  bool get isStudying => _isStudying;
  bool get isPaused => _isPaused;
  Duration get studyTime => _studyTime;
  Duration get pauseTime => _pauseTime;
  bool get enablePauseReminder => _enablePauseReminder;
  Duration get studyDuration => _studyDuration;
  Duration get pauseDuration => _pauseDuration;
  bool get enableSound => _enableSound;
  bool get showFloatingClock => _showFloatingClock;
  bool get floatingClockDismissed => _floatingClockDismissed;
  bool get shouldShowFloatingClock =>
      _showFloatingClock && !_floatingClockDismissed;
  int get themeModeIndex => _themeModeIndex;
  int get fontSize => _fontSize;

  /// 0 = claro, 1 = escuro, 2 = automático (sistema).
  ThemeMode get themeMode {
    switch (_themeModeIndex) {
      case 0:
        return ThemeMode.light;
      case 1:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Escala de texto relativa ao padrão 16pt.
  double get textScaleFactor => _fontSize / 16.0;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _studyDuration = Duration(minutes: prefs.getInt('studyDuration') ?? 50);
    _pauseDuration = Duration(minutes: prefs.getInt('pauseDuration') ?? 10);
    _enableSound = prefs.getBool('enableSound') ?? true;
    _showFloatingClock = prefs.getBool('showFloatingClock') ?? true;
    _enablePauseReminder = prefs.getBool('enablePauseReminder') ?? true;
    _themeModeIndex = prefs.getInt('themeModeIndex') ?? 0;
    _fontSize = prefs.getInt('fontSize') ?? 16;
    notifyListeners();
  }

  Future<void> saveSettings({
    int? studyDuration,
    int? pauseDuration,
    bool? enableSound,
    bool? showFloatingClock,
    bool? enablePauseReminder,
    int? themeModeIndex,
    int? fontSize,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (studyDuration != null) {
      _studyDuration = Duration(minutes: studyDuration);
      await prefs.setInt('studyDuration', studyDuration);
    }
    if (pauseDuration != null) {
      _pauseDuration = Duration(minutes: pauseDuration);
      await prefs.setInt('pauseDuration', pauseDuration);
    }
    if (enableSound != null) {
      _enableSound = enableSound;
      await prefs.setBool('enableSound', enableSound);
    }
    if (showFloatingClock != null) {
      _showFloatingClock = showFloatingClock;
      await prefs.setBool('showFloatingClock', showFloatingClock);
      if (showFloatingClock) {
        _floatingClockDismissed = false;
      }
    }
    if (enablePauseReminder != null) {
      _enablePauseReminder = enablePauseReminder;
      await prefs.setBool('enablePauseReminder', enablePauseReminder);
    }
    if (themeModeIndex != null) {
      _themeModeIndex = themeModeIndex;
      await prefs.setInt('themeModeIndex', themeModeIndex);
    }
    if (fontSize != null) {
      _fontSize = fontSize;
      await prefs.setInt('fontSize', fontSize);
    }
    notifyListeners();
  }

  Future<void> saveThemeModeIndex(int index) async {
    await saveSettings(themeModeIndex: index);
  }

  Future<void> saveFontSize(int size) async {
    await saveSettings(fontSize: size);
  }

  String pickRandomPauseMessage() {
    final list = StudyPauseMessages.all;
    if (list.isEmpty) {
      return 'Aproveite a pausa para descansar corpo e mente.';
    }
    return list[_random.nextInt(list.length)];
  }

  void dismissFloatingClock() {
    _floatingClockDismissed = true;
    notifyListeners();
  }

  void restoreFloatingClock() {
    _floatingClockDismissed = false;
    notifyListeners();
  }

  void iniciarEstudo() {
    if (_isStudying) return;
    _isStudying = true;
    _isPaused = false;
    _alertShown = false;
    _studyTimer?.cancel();
    _pauseTimer?.cancel();
    _studyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _studyTime += const Duration(seconds: 1);
      _studyTimeController.add(_studyTime);

      if (_enablePauseReminder &&
          !_alertShown &&
          _studyTime >= _studyDuration) {
        _alertShown = true;
        _alertController.add('pause_reminder');
        playAlarm();
      }
    });
  }

  void pausarEstudo() {
    _isStudying = false;
    _isPaused = true;
    _studyTimer?.cancel();
  }

  void resetarEstudo() {
    _studyTimer?.cancel();
    _pauseTimer?.cancel();
    _studyTime = Duration.zero;
    _pauseTime = Duration.zero;
    _isStudying = false;
    _isPaused = false;
    _alertShown = false;
    _studyTimeController.add(_studyTime);
    _pauseTimeController.add(_pauseTime);
  }

  void iniciarPausa() {
    _pauseTime = _pauseDuration;
    _pauseTimer?.cancel();
    playAlarm();
    _alertController.add('pause_started');
    _pauseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _pauseTime -= const Duration(seconds: 1);
      _pauseTimeController.add(_pauseTime);

      if (_pauseTime <= Duration.zero) {
        _pauseTimer?.cancel();
        _alertController.add('pause_end');
        playAlarm();
      }
    });
    notifyListeners();
  }

  /// Encerra a pausa, toca alerta e reinicia o ciclo de estudo.
  void retomarEstudoAposPausa() {
    cancelarPausa();
    _isPaused = false;
    _studyTime = Duration.zero;
    _alertShown = false;
    _studyTimeController.add(_studyTime);
    playAlarm();
    iniciarEstudo();
    notifyListeners();
  }

  void cancelarPausa() {
    _pauseTimer?.cancel();
    _pauseTime = Duration.zero;
    _pauseTimeController.add(_pauseTime);
  }

  /// Alerta tipo despertador (vários bipes + vibração leve).
  Future<void> playAlarm() async {
    if (!_enableSound) return;

    for (var i = 0; i < 4; i++) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
      if (i < 3) {
        await Future<void>.delayed(const Duration(milliseconds: 380));
      }
    }

    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
    } catch (_) {}
  }

  @override
  void dispose() {
    _studyTimer?.cancel();
    _pauseTimer?.cancel();
    _studyTimeController.close();
    _pauseTimeController.close();
    _alertController.close();
    _audioPlayer.dispose();
    super.dispose();
  }
}
