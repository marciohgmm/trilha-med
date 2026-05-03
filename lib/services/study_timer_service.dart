import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudyTimerService {
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

  final AudioPlayer _audioPlayer = AudioPlayer();

  // Streams para notificar mudanças
  final StreamController<Duration> _studyTimeController = StreamController<Duration>.broadcast();
  final StreamController<Duration> _pauseTimeController = StreamController<Duration>.broadcast();
  final StreamController<String> _alertController = StreamController<String>.broadcast();

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

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _studyDuration = Duration(minutes: prefs.getInt('studyDuration') ?? 50);
    _pauseDuration = Duration(minutes: prefs.getInt('pauseDuration') ?? 10);
    _enableSound = prefs.getBool('enableSound') ?? true;
    _showFloatingClock = prefs.getBool('showFloatingClock') ?? true;
    _enablePauseReminder = prefs.getBool('enablePauseReminder') ?? true;
  }

  Future<void> saveSettings({
    int? studyDuration,
    int? pauseDuration,
    bool? enableSound,
    bool? showFloatingClock,
    bool? enablePauseReminder,
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
    }
    if (enablePauseReminder != null) {
      _enablePauseReminder = enablePauseReminder;
      await prefs.setBool('enablePauseReminder', enablePauseReminder);
    }
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

      if (_enablePauseReminder && !_alertShown && _studyTime >= _studyDuration) {
        _alertShown = true;
        _alertController.add('pause_reminder');
        _playSound();
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
    _pauseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _pauseTime -= const Duration(seconds: 1);
      _pauseTimeController.add(_pauseTime);

      if (_pauseTime <= Duration.zero) {
        _pauseTimer?.cancel();
        _alertController.add('pause_end');
        _playSound();
      }
    });
  }

  void cancelarPausa() {
    _pauseTimer?.cancel();
    _pauseTime = Duration.zero;
    _pauseTimeController.add(_pauseTime);
  }

  void _playSound() async {
    if (!_enableSound) return;
    try {
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
    } catch (e) {
      // Handle error
    }
  }

  void dispose() {
    _studyTimer?.cancel();
    _pauseTimer?.cancel();
    _studyTimeController.close();
    _pauseTimeController.close();
    _alertController.close();
    _audioPlayer.dispose();
  }
}