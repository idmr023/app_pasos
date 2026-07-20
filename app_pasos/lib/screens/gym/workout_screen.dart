import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

class _WorkoutScreenState extends State<WorkoutScreen>
    with SingleTickerProviderStateMixin {
  int _currentExerciseIndex = 0;
  int _currentSet = 1;
  bool _isResting = false;
  bool _isComplete = false;
  int _totalXpGained = 0;
  final Set<String> _completedSets = {};
  final Map<String, double> _setWeights = {};
  final Map<String, TextEditingController> _weightControllers = {};

  String _setKey(int exerciseIndex, int setNumber) => '$exerciseIndex-$setNumber';

  TextEditingController _getWeightController(String key, double weight) {
    if (!_weightControllers.containsKey(key)) {
      _weightControllers[key] = TextEditingController(
        text: weight.toStringAsFixed(1),
      );
    }
    return _weightControllers[key]!;
  }
  bool _useLbs = false;
  final Stopwatch _totalTimer = Stopwatch();
  late AnimationController _confettiController;
  late Animation<double> _confettiAnimation;
  final _confettiColors = [
    AppTheme.primary, AppTheme.secondary, AppTheme.tertiary,
    AppTheme.gold, Colors.pinkAccent, Colors.amberAccent,
  ];
  double? _exercisePr;

  RoutineExercise get _currentExercise => widget.exercises[_currentExerciseIndex];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _totalTimer.start();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _confettiAnimation = CurvedAnimation(
      parent: _confettiController,
      curve: Curves.easeOut,
    );
    _loadPr();
  }

  void _loadPr() {
    final gym = context.read<GymProvider>();
    final exId = _currentExercise.exerciseId;
    _exercisePr = gym.getPrForExercise(exId);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _totalTimer.stop();
    _confettiController.dispose();
    for (final c in _weightControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isLastSetOfCurrentExercise =>
      _currentSet >= _currentExercise.sets;

  void _markSetComplete() {
    final key = _setKey(_currentExerciseIndex, _currentSet);
    if (_completedSets.contains(key)) return;

    setState(() {
      _completedSets.add(key);
      _totalXpGained += 5;
    });

    // Descanso entre series (o entre ejercicios si es la última serie)
    if (_isLastSetOfCurrentExercise && _currentExerciseIndex + 1 >= widget.exercises.length) {
      _finishWorkout();
    } else {
      setState(() => _isResting = true);
    }
  }

  void _onRestComplete() {
    if (_isLastSetOfCurrentExercise) {
      final nextIdx = _currentExerciseIndex + 1;
      if (nextIdx >= widget.exercises.length) {
        _finishWorkout();
        return;
      }
      setState(() {
        _isResting = false;
        _currentExerciseIndex = nextIdx;
        _currentSet = 1;
        while (_currentSet <= widget.exercises[_currentExerciseIndex].sets &&
            _completedSets.contains(_setKey(_currentExerciseIndex, _currentSet))) {
          _currentSet++;
        }
      });
      _loadPr();
    } else {
      setState(() {
        _isResting = false;
        _currentSet++;
      });
    }
  }

  void _previousExercise() {
    if (_currentExerciseIndex > 0) {
      setState(() {
        _currentExerciseIndex--;
        _currentSet = 1;
        _isResting = false;
        _loadPr();
      });
    }
  }

  Future<void> _finishWorkout() async {
    _totalTimer.stop();
    setState(() => _isComplete = true);
    _confettiController.forward();

    final completedExercises = widget.exercises.map((e) {
      double maxWeight = 0;
      for (int s = 1; s <= e.sets; s++) {
        final w = _setWeights[_setKey(widget.exercises.indexOf(e), s)] ?? 0;
        if (w > maxWeight) maxWeight = w;
      }
      return {
        'exerciseId': e.exerciseId,
        'exerciseName': e.exerciseName,
        'setsCompleted': e.sets,
        'repsCompleted': e.reps,
        'weightKg': maxWeight,
      };
    }).toList();

    final gym = context.read<GymProvider>();
    await gym.logWorkout({
      'routineName': widget.routineName,
      'duration': _totalTimer.elapsed.inSeconds,
      'exercises': completedExercises,
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
                      const SizedBox(height: 16),
                      _buildWeightInput(),
                      const SizedBox(height: 16),
                      if (_isResting)
                        _buildRestTimer()
                      else
                        _buildSetButton(),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_currentExerciseIndex + 1}/${widget.exercises.length}',
                style: AppTheme.titleLarge.copyWith(color: AppTheme.primary),
              ),
              if (_totalXpGained > 0)
                Text('+$_totalXpGained XP', style: TextStyle(color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final totalSets = widget.exercises.fold<int>(0, (sum, e) => sum + e.sets);
    final completedSets = _completedSets.length;
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
    final imageUrl = '';
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppTheme.surface.withValues(alpha: 0.3),
      ),
      child: imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                errorWidget: (_, __, ___) => _buildPlaceholder(),
              ),
            )
          : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.fitness_center,
        size: 64,
        color: AppTheme.darkGrey,
      ),
    );
  }

  Widget _buildExerciseInfo(RoutineExercise ex) {
    final setsDone = _completedSets.where((k) => k.startsWith('$_currentExerciseIndex-')).length;
    return GlassCard(
      width: double.infinity,
      child: Column(
        children: [
          Text(
            ex.exerciseName.isNotEmpty ? ex.exerciseName : 'Ejercicio',
            style: AppTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${ex.sets} series × ${ex.reps}',
            style: AppTheme.titleLarge.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            '$setsDone de ${ex.sets} series completadas',
            style: TextStyle(color: setsDone == ex.sets ? AppTheme.tertiary : AppTheme.darkGrey, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightInput() {
    final key = _setKey(_currentExerciseIndex, _currentSet);
    final alreadyDone = _completedSets.contains(key);
    final currentWeight = _setWeights[key] ?? 0;
    final controller = _getWeightController(key, currentWeight);

    if (alreadyDone) return const SizedBox.shrink();

    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.monitor_weight, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text('PESO', style: AppTheme.labelLarge),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'lbs',
                    style: TextStyle(
                      fontSize: 12,
                      color: _useLbs ? AppTheme.grey : AppTheme.darkGrey,
                      fontWeight: _useLbs ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  Switch(
                    value: _useLbs,
                    activeTrackColor: AppTheme.primary.withValues(alpha: 0.3),
                    activeThumbColor: AppTheme.primary,
                    onChanged: (v) => setState(() {
                      _useLbs = v;
                      controller.text = v
                          ? (currentWeight / 0.453592).toStringAsFixed(1)
                          : currentWeight.toStringAsFixed(1);
                    }),
                  ),
                  Text(
                    'kg',
                    style: TextStyle(
                      fontSize: 12,
                      color: !_useLbs ? AppTheme.grey : AppTheme.darkGrey,
                      fontWeight: !_useLbs ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                IconButton(
                    icon: const Icon(Icons.remove, color: AppTheme.primary, size: 18),
                    onPressed: () {
                      final val = ((_useLbs ? currentWeight / 0.453592 : currentWeight) - 2.5).clamp(0.0, 999.0).toDouble();
                      setState(() {
                        _setWeights[key] = _useLbs ? val * 0.453592 : val;
                        controller.text = val.toStringAsFixed(1);
                      });
                    },
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(2),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: TextFormField(
                        controller: controller,
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onFieldSubmitted: (v) {
                          final parsed = double.tryParse(v) ?? 0;
                          setState(() {
                            _setWeights[key] = _useLbs ? parsed * 0.453592 : parsed;
                          });
                        },
                      ),
                    ),
                  ),
                  Text(
                    _useLbs ? 'lbs' : 'kg',
                    style: TextStyle(color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: AppTheme.primary, size: 18),
                    onPressed: () {
                      final val = ((_useLbs ? currentWeight / 0.453592 : currentWeight) + 2.5).clamp(0.0, 999.0).toDouble();
                      setState(() {
                        _setWeights[key] = _useLbs ? val * 0.453592 : val;
                        controller.text = val.toStringAsFixed(1);
                      });
                    },
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(2),
                  ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (currentWeight > 0 && _exercisePr != null && currentWeight > _exercisePr!)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events, color: AppTheme.gold, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '¡NUEVA MARCA PERSONAL!',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          if (_exercisePr != null && _exercisePr! > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'PR actual: ${_exercisePr!.toInt()}kg',
                style: AppTheme.bodySmall.copyWith(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSetButton() {
    final key = _setKey(_currentExerciseIndex, _currentSet);
    final alreadyDone = _completedSets.contains(key);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'SERIE $_currentSet',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 200,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: alreadyDone ? null : _markSetComplete,
            icon: Icon(alreadyDone ? Icons.check_circle : Icons.check, size: 24),
            label: Text(alreadyDone ? 'COMPLETADA' : 'COMPLETAR SERIE', style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(
              backgroundColor: alreadyDone ? AppTheme.tertiary : AppTheme.primary,
              disabledBackgroundColor: AppTheme.tertiary.withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white70,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('+5 XP', style: TextStyle(color: AppTheme.gold, fontSize: 13, fontWeight: FontWeight.w700)),
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
                    _markSetComplete();
                  }
                },
                icon: Icon(
                  _isResting ? Icons.skip_next : Icons.check,
                  size: 20,
                ),
                label: Text(
                  _isResting ? 'SALTAR DESCANSO' : 'COMPLETAR SERIE',
                ),
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
        child: AnimatedBuilder(
          animation: _confettiAnimation,
          builder: (context, child) {
            return Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events, size: 100,
                          color: AppTheme.gold.withValues(alpha: 0.8 + _confettiAnimation.value * 0.2)),
                        const SizedBox(height: 16),
                        Text('¡ENTRENAMIENTO COMPLETADO!',
                          style: AppTheme.headlineMedium.copyWith(
                            color: AppTheme.gold,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                                style: AppTheme.displayMedium.copyWith(color: AppTheme.primary),
                              ),
                              const SizedBox(height: 8),
                              Text('DURACIÓN', style: AppTheme.bodySmall),
                              const SizedBox(height: 16),
                              Text(
                                '+$_totalXpGained XP',
                                style: AppTheme.titleLarge.copyWith(color: AppTheme.gold),
                              ),
                              Text('GANADOS', style: AppTheme.bodySmall),
                            ],
                          ),
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
                            child: const Text('FINALIZAR',
                              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_confettiAnimation.value > 0)
                  ...List.generate(30, (i) {
                    final delay = (i / 30) * _confettiAnimation.value;
                    final x = sin(i * 1.7 + delay * 5) * 150;
                    final y = -(i % 20) * 30 - 50 + (1 - _confettiAnimation.value) * 400;
                    return Positioned(
                      left: MediaQuery.of(context).size.width / 2 + x - 8,
                      top: MediaQuery.of(context).size.height / 2 + y,
                      child: Opacity(
                        opacity: (1 - _confettiAnimation.value) * (1 - i / 30),
                        child: Icon(
                          Icons.star,
                          color: _confettiColors[i % _confettiColors.length],
                          size: 16 + (i % 4) * 4.0,
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
