import 'package:flutter/material.dart';

import '../services/study_timer_service.dart';

/// Relógio flutuante: arraste para mover; solte na lixeira para ocultar.
class StudyTimerOverlay extends StatefulWidget {
  const StudyTimerOverlay({super.key});

  @override
  State<StudyTimerOverlay> createState() => _StudyTimerOverlayState();
}

class _StudyTimerOverlayState extends State<StudyTimerOverlay> {
  final StudyTimerService _service = StudyTimerService();
  Duration _studyTime = Duration.zero;
  Duration _pauseTime = Duration.zero;

  Offset? _pos;
  Size _layoutSize = Size.zero;
  bool _isDragging = false;
  bool _overTrash = false;

  static const double _pillWidth = 132;
  static const double _pillHeight = 40;
  static const double _trashHitRadius = 58;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
    _service.studyTimeStream.listen((time) {
      if (mounted) setState(() => _studyTime = time);
    });
    _service.pauseTimeStream.listen((time) {
      if (mounted) setState(() => _pauseTime = time);
    });
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Offset _clamp(Offset p, Size box) {
    if (box.width <= 0 || box.height <= 0) return p;
    const m = 8.0;
    return Offset(
      p.dx.clamp(m, box.width - _pillWidth - m),
      p.dy.clamp(m, box.height - _pillHeight - m),
    );
  }

  Offset _trashCenter(Size box) {
    final safe = MediaQuery.paddingOf(context);
    return Offset(
      box.width / 2,
      box.height - safe.bottom - 72,
    );
  }

  bool _isOverTrash(Offset pillTopLeft, Size box) {
    final trash = _trashCenter(box);
    final pillCenter = Offset(
      pillTopLeft.dx + _pillWidth / 2,
      pillTopLeft.dy + _pillHeight / 2,
    );
    return (pillCenter - trash).distance <= _trashHitRadius;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Duration get _displayTime =>
      _service.isPaused ? _pauseTime : _studyTime;

  @override
  Widget build(BuildContext context) {
    if (!_service.shouldShowFloatingClock ||
        (!_service.isStudying && !_service.isPaused)) {
      return const SizedBox.shrink();
    }

    final box = MediaQuery.sizeOf(context);
    _layoutSize = box;

    if (box.width > 0 && box.height > 0) {
      _pos ??= Offset(
        box.width - _pillWidth - 16,
        (box.height * 0.22).clamp(48.0, box.height - _pillHeight - 16),
      );
      _pos = _clamp(_pos!, box);
    }

    final pos = _pos ?? Offset.zero;
    final trashActive = _isDragging && _overTrash;

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        if (_isDragging)
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 20,
            child: Center(
              child: _TrashDropTarget(active: trashActive),
            ),
          ),
        Positioned(
          left: pos.dx,
          top: pos.dy,
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onPanStart: (_) {
              setState(() {
                _isDragging = true;
                _overTrash = false;
              });
            },
            onPanUpdate: (details) {
              setState(() {
                final base = _pos ?? Offset.zero;
                final next = _clamp(base + details.delta, _layoutSize);
                _pos = next;
                _overTrash = _isOverTrash(next, _layoutSize);
              });
            },
            onPanEnd: (_) {
              if (_overTrash) {
                _service.dismissFloatingClock();
              }
              setState(() {
                _isDragging = false;
                _overTrash = false;
              });
            },
            onPanCancel: () {
              setState(() {
                _isDragging = false;
                _overTrash = false;
              });
            },
            child: AnimatedScale(
              scale: _isDragging ? 1.06 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: Material(
                color: Colors.transparent,
                elevation: _isDragging ? 12 : 6,
                borderRadius: BorderRadius.circular(22),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _service.isPaused
                        ? const Color(0xFF0D9488).withValues(alpha: 0.92)
                        : Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: trashActive
                          ? Colors.redAccent
                          : Colors.white.withValues(alpha: 0.15),
                      width: trashActive ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.drag_indicator,
                        color: Colors.white.withValues(alpha: 0.75),
                        size: 18,
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _service.isPaused ? Icons.coffee : Icons.timer,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(_displayTime),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrashDropTarget extends StatelessWidget {
  final bool active;

  const _TrashDropTarget({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: active ? 88 : 72,
      height: active ? 88 : 72,
      decoration: BoxDecoration(
        color: active
            ? Colors.red.withValues(alpha: 0.22)
            : Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? Colors.redAccent : Colors.white54,
          width: active ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delete_outline,
            color: active ? Colors.redAccent : Colors.white,
            size: active ? 34 : 28,
          ),
          if (active)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Soltar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Ocultar',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 9,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
