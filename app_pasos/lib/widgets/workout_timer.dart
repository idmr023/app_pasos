import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../config/theme.dart';

class WorkoutTimer extends StatefulWidget {
  final int totalSeconds;
  final VoidCallback? onComplete;
  final bool autoStart;
  final bool running;

  const WorkoutTimer({
    super.key,
    required this.totalSeconds,
    this.onComplete,
    this.autoStart = true,
    this.running = true,
  });

  @override
  State<WorkoutTimer> createState() => _WorkoutTimerState();
}

class _WorkoutTimerState extends State<WorkoutTimer> {
  Timer? _timer;
  late DateTime _startTime;
  late int _remaining;
  bool _completed = false;
  bool _running = true;
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _remaining = widget.totalSeconds;
    _running = widget.running && widget.autoStart;
    if (_running) _startTimer();
  }

  @override
  void didUpdateWidget(WorkoutTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.totalSeconds != oldWidget.totalSeconds) {
      _remaining = widget.totalSeconds;
      _completed = false;
      _running = widget.running;
      _timer?.cancel();
      if (_running) _startTimer();
    }
    if (widget.running != oldWidget.running) {
      if (widget.running && !_running) {
        _running = true;
        _startTimer();
      } else if (!widget.running && _running) {
        _running = false;
        _timer?.cancel();
      }
    }
  }

  void _startTimer() {
    _startTime = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || !_running) return;
      final elapsed = DateTime.now().difference(_startTime).inSeconds;
      final remaining = max(0, widget.totalSeconds - elapsed);
      if (remaining != _remaining) {
        setState(() => _remaining = remaining);
      }
      if (remaining <= 0 && !_completed) {
        _completed = true;
        _running = false;
        _timer?.cancel();
        _player.play(UrlSource('https://actions.google.com/sounds/v1/alarms/beep_short.ogg')).catchError((_) {});
        widget.onComplete?.call();
      }
    });
  }

  void pause() {
    if (!_running) return;
    setState(() => _running = false);
    _timer?.cancel();
  }

  void resume() {
    if (_running || _completed) return;
    setState(() => _running = true);
    _startTimer();
  }

  void skip() {
    _timer?.cancel();
    setState(() {
      _remaining = 0;
      _completed = true;
      _running = false;
    });
    widget.onComplete?.call();
  }

  void reset() {
    _timer?.cancel();
    setState(() {
      _remaining = widget.totalSeconds;
      _completed = false;
      _running = widget.autoStart;
    });
    if (_running && widget.autoStart) _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remaining % 60).toString().padLeft(2, '0');
    final progress = widget.totalSeconds > 0
        ? _remaining / widget.totalSeconds
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _remaining <= 5 ? AppTheme.error : AppTheme.primary,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$minutes:$seconds',
                    style: AppTheme.displayMedium.copyWith(
                      fontSize: 42,
                      color: _remaining <= 5 ? AppTheme.error : Colors.white,
                    ),
                  ),
                  Text(
                    _completed ? 'TERMINADO' : _running ? '' : 'PAUSADO',
                    style: TextStyle(
                      color: _completed
                          ? AppTheme.secondary
                          : _running
                              ? AppTheme.darkGrey
                              : AppTheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!_completed) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_running)
                GestureDetector(
                  onTap: pause,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.pause, color: AppTheme.primary, size: 18),
                        SizedBox(width: 4),
                        Text('PAUSAR', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: resume,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.play_arrow, color: AppTheme.secondary, size: 18),
                        SizedBox(width: 4),
                        Text('REANUDAR', style: TextStyle(color: AppTheme.secondary, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: skip,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.skip_next, color: AppTheme.darkGrey, size: 18),
                      const SizedBox(width: 4),
                      Text('SALTAR', style: TextStyle(color: AppTheme.darkGrey, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}