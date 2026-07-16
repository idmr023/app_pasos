import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../config/theme.dart';
import '../../providers/gym_provider.dart';
import '../../models/routine.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/workout_timer.dart';

class WorkoutScreen extends StatefulWidget {
  final String routineName;
  final List<RoutineExercise> exercises;

  const WorkoutScreen({
    super.key,
    required this.routineName,
    required this.exercises,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  int _currentExerciseIndex = 0;
  int _currentSet = 1;
  bool _isResting = false;
  bool _isComplete = false;
  final Stopwatch _totalTimer = Stopwatch();

  RoutineExercise get _currentExercise => widget.exercises[_currentExerciseIndex];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _totalTimer.start();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _totalTimer.stop();
    super.dispose();
  }

  void _onExerciseComplete() {
    if (_currentSet < _currentExercise.sets) {
      setState(() {
        _currentSet++;
        _isResting = true;
      });
    } else {
      _nextExercise();
    }
  }

  void _onRestComplete() {
    setState(() => _isResting = false);
  }

  void _nextExercise() {
    if (_currentExerciseIndex + 1 < widget.exercises.length) {
      setState(() {
        _currentExerciseIndex++;
        _currentSet = 1;
        _isResting = false;
      });
    } else {
      _finishWorkout();
    }
  }

  void _previousExercise() {
    if (_currentExerciseIndex > 0) {
      setState(() {
        _currentExerciseIndex--;
        _currentSet = 1;
        _isResting = false;
      });
    }
  }

  Future<void> _finishWorkout() async {
    _totalTimer.stop();
    setState(() => _isComplete = true);

    final gym = context.read<GymProvider>();
    await gym.logWorkout({
      'routineName': widget.routineName,
      'duration': _totalTimer.elapsed.inSeconds,
      'exercises': widget.exercises.map((e) => {
        'exerciseId': e.exerciseId,
        'exerciseName': e.exercise?.name ?? '',
        'setsCompleted': e.sets,
        'repsCompleted': e.reps,
      }).toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isComplete) {
      return _buildCompleteScreen();
    }

    final ex = _currentExercise;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.background, Color(0xFF0A0A1A), AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildProgress(),
                      const SizedBox(height: 24),
                      _buildExerciseImage(ex),
                      const SizedBox(height: 16),
                      _buildExerciseInfo(ex),
                      const SizedBox(height: 24),
                      if (_isResting)
                        _buildRestTimer()
                      else
                        _buildExerciseTimer(ex),
                    ],
                  ),
                ),
              ),
              _buildControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final totalMins = (_totalTimer.elapsed.inSeconds ~/ 60);
    final totalSecs = (_totalTimer.elapsed.inSeconds % 60);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.routineName, style: AppTheme.titleMedium),
                Text(
                  '${totalMins.toString().padLeft(2, '0')}:${totalSecs.toString().padLeft(2, '0')}',
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${_currentExerciseIndex + 1}/${widget.exercises.length}',
            style: AppTheme.titleLarge.copyWith(color: AppTheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final totalSets = widget.exercises.fold<int>(0, (sum, e) => sum + e.sets);
    final completedSets = widget.exercises
        .take(_currentExerciseIndex)
        .fold<int>(0, (sum, e) => sum + e.sets) + (_currentSet - 1);
    final progress = totalSets > 0 ? completedSets / totalSets : 0.0;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Serie $_currentSet de ${_currentExercise.sets}',
          style: AppTheme.labelLarge,
        ),
      ],
    );
  }

  Widget _buildExerciseImage(RoutineExercise ex) {
    final imageUrl = ex.exercise?.imageUrl ?? '';
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppTheme.surface.withValues(alpha: 0.3),
      ),
      child: imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(ex),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary.withValues(alpha: 0.3),
                    ),
                  );
                },
              ),
            )
          : _buildPlaceholder(ex),
    );
  }

  Widget _buildPlaceholder(RoutineExercise ex) {
    return Center(
      child: Icon(
        _currentExercise.exercise?.category == 'warmup'
            ? Icons.whatshot
            : Icons.fitness_center,
        size: 64,
        color: AppTheme.darkGrey,
      ),
    );
  }

  Widget _buildExerciseInfo(RoutineExercise ex) {
    return GlassCard(
      width: double.infinity,
      child: Column(
        children: [
          Text(
            ex.exercise?.name ?? 'Ejercicio',
            style: AppTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${ex.sets} series × ${ex.reps}',
            style: AppTheme.titleLarge.copyWith(color: AppTheme.primary),
          ),
          if (ex.exercise?.description != null && ex.exercise!.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              ex.exercise!.description,
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseTimer(RoutineExercise ex) {
    return Column(
      children: [
        const Text(
          'TIEMPO DE TRABAJO',
          style: TextStyle(
            color: AppTheme.darkGrey,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        WorkoutTimer(
          totalSeconds: 45,
          onComplete: _onExerciseComplete,
        ),
      ],
    );
  }

  Widget _buildRestTimer() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer, color: AppTheme.tertiary, size: 20),
            const SizedBox(width: 8),
            Text(
              'DESCANSO',
              style: TextStyle(
                color: AppTheme.tertiary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        WorkoutTimer(
          totalSeconds: _currentExercise.restTime,
          onComplete: _onRestComplete,
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentExerciseIndex > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _previousExercise,
                  icon: const Icon(Icons.skip_previous, size: 18),
                  label: const Text('ANTERIOR'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.darkGrey,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            if (_currentExerciseIndex > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_isResting) {
                    _onRestComplete();
                  } else {
                    _onExerciseComplete();
                  }
                },
                icon: Icon(
                  _isResting ? Icons.play_arrow : Icons.check,
                  size: 20,
                ),
                label: Text(_isResting ? 'TERMINAR DESCANSO' : 'SIGUIENTE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteScreen() {
    final mins = (_totalTimer.elapsed.inSeconds ~/ 60);
    final secs = (_totalTimer.elapsed.inSeconds % 60);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.background, Color(0xFF0A0A1A), AppTheme.background],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 80, color: AppTheme.secondary),
                const SizedBox(height: 24),
                Text('ENTRENAMIENTO COMPLETADO', style: AppTheme.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text(
                  '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                  style: AppTheme.displayMedium.copyWith(color: AppTheme.primary),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('FINALIZAR', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}