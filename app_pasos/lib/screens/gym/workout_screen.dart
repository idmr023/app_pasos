import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../providers/gym_provider.dart';
import '../../models/routine.dart';
import '../../models/workout.dart';
import '../../models/exercise_progress.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/workout_timer.dart';

class WorkoutScreen extends StatefulWidget {
  final String routineName;
  final List<RoutineExercise> exercises;
  /// Rutina guardada de origen (para que el backend lea rango e incremento).
  final String? routineId;

  const WorkoutScreen({
    super.key,
    required this.routineName,
    required this.exercises,
    this.routineId,
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
  /// Peso por serie, siempre en kg (la unidad es solo de visualización).
  final Map<String, double> _setWeights = {};
  /// Repeticiones logradas por serie (por defecto, el objetivo).
  final Map<String, int> _setReps = {};
  /// Repeticiones en reserva respondidas en la calibración.
  final Map<String, int> _setRir = {};
  /// Series cuyo peso eligió el usuario (no se sobrescriben con sugerencias).
  final Set<String> _touchedWeights = {};
  final Map<String, TextEditingController> _weightControllers = {};
  /// Unidad elegida en esta sesión por exerciseId (si no, la guardada en el progreso).
  final Map<String, String> _unitByExercise = {};
  /// Ejercicios (índice) cuya base ya se encontró en esta sesión.
  final Set<int> _calibrated = {};
  bool _savingWorkout = false;
  static const double _kgPerLb = 0.453592;

  String _setKey(int exerciseIndex, int setNumber) => '$exerciseIndex-$setNumber';

  TextEditingController _getWeightController(String key, String text) {
    if (!_weightControllers.containsKey(key)) {
      _weightControllers[key] = TextEditingController(text: text);
    }
    return _weightControllers[key]!;
  }

  ExerciseProgress? _progressOf(int i) =>
      context.read<GymProvider>().progressFor(widget.exercises[i].exerciseId);

  String _unitFor(int i) =>
      _unitByExercise[widget.exercises[i].exerciseId] ?? _progressOf(i)?.unit ?? 'kg';

  bool get _useLbs => _unitFor(_currentExerciseIndex) == 'lb';

  /// Peso en la unidad de visualización del ejercicio [i], con 1 decimal.
  String _fmtInput(int i, double kg) =>
      (_unitFor(i) == 'lb' ? kg / _kgPerLb : kg).toStringAsFixed(1);

  /// Peso con unidad para textos: "17.5 kg" o "38.6 lb".
  String _fmtWeight(int i, double kg) => _unitFor(i) == 'lb'
      ? '${(kg / _kgPerLb).toStringAsFixed(1)} lb'
      : '${formatKg(kg)} kg';

  int _targetRepsFor(int i) =>
      _progressOf(i)?.next?.targetReps ?? widget.exercises[i].defaultTargetReps;

  int _targetSecondsFor(int i) {
    final p = _progressOf(i);
    final fromNext = p?.next?.targetSeconds;
    if (fromNext != null && fromNext > 0) return fromNext;
    if (p != null && p.currentSeconds > 0) return p.currentSeconds;
    return widget.exercises[i].targetSeconds;
  }

  bool _needsCalibration(int i) {
    final ex = widget.exercises[i];
    if (ex.isTimed || _calibrated.contains(i)) return false;
    final p = _progressOf(i);
    return p == null || p.isCalibrating;
  }

  void _setWeight(int i, int set, double kg, {bool touched = false}) {
    final key = _setKey(i, set);
    _setWeights[key] = kg;
    if (touched) _touchedWeights.add(key);
    _weightControllers[key]?.text = _fmtInput(i, kg);
  }
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProgress());
  }

  /// Carga la progresión de los ejercicios y precarga el peso sugerido por serie.
  Future<void> _loadProgress() async {
    final gym = context.read<GymProvider>();
    await gym.loadProgress(widget.exercises.map((e) => e.exerciseId).toSet().toList());
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < widget.exercises.length; i++) {
        final p = _progressOf(i);
        if (p == null) continue;
        for (int s = 1; s <= widget.exercises[i].sets; s++) {
          final key = _setKey(i, s);
          if (_touchedWeights.contains(key) || _completedSets.contains(key)) continue;
          final w = p.weightForSet(s);
          if (w > 0) _setWeight(i, s, w);
        }
      }
    });
  }

  /// Al pasar de serie, la siguiente hereda el peso de la anterior, salvo que
  /// haya una sugerencia del motor que el usuario no tocó (p. ej. el puente).
  void _carryWeight(int i, int fromSet) {
    final from = _setKey(i, fromSet);
    final to = _setKey(i, fromSet + 1);
    if (_touchedWeights.contains(to) || _completedSets.contains(to)) return;
    final p = _progressOf(i);
    if (p?.next?.isBridge == true) return;
    if (p != null && p.weightForSet(fromSet + 1) > 0 && !_touchedWeights.contains(from)) return;
    final w = _setWeights[from] ?? 0;
    if (w > 0) _setWeight(i, fromSet + 1, w);
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

  Future<void> _markSetComplete() async {
    final idx = _currentExerciseIndex;
    final set = _currentSet;
    final key = _setKey(idx, set);
    if (_completedSets.contains(key)) return;

    setState(() {
      _setReps.putIfAbsent(key, () => _targetRepsFor(idx));
      _completedSets.add(key);
      _totalXpGained += 5;
    });

    // Calibración: tras cada serie con peso, preguntar las repeticiones en reserva.
    if (_needsCalibration(idx) && (_setWeights[key] ?? 0) > 0) {
      await _askReserve(idx, set);
      if (!mounted) return;
    }

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
        _carryWeight(_currentExerciseIndex, _currentSet);
        _isResting = false;
        _currentSet++;
      });
    }
  }

  /// Asistente de calibración: "¿Cuántas repeticiones te quedaban?"
  Future<void> _askReserve(int idx, int set) async {
    final rir = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('¿Cuántas repeticiones te quedaban?', style: AppTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Así encontramos tu peso base', style: AppTheme.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              for (final opt in const [('4 o más', 4), ('2 o 3', 2), ('0 o 1', 0), ('No llegué', -1)])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, opt.$2),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(opt.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (rir == null || !mounted) return;

    final ex = widget.exercises[idx];
    final key = _setKey(idx, set);
    final w = _setWeights[key] ?? 0;
    final step = ex.incrementKg > 0 ? ex.incrementKg : 2.5;
    final double nextW;
    final String msg;
    if (rir >= 4) {
      nextW = w + step;
      msg = 'Te sobraba: prueba ${_fmtWeight(idx, nextW)} en la siguiente serie';
    } else if (rir >= 2) {
      nextW = w;
      _calibrated.add(idx);
      msg = '${_fmtWeight(idx, w)} queda como tu peso base';
    } else {
      nextW = max(0.0, w - step);
      msg = 'Muy pesado: prueba ${_fmtWeight(idx, nextW)} en la siguiente serie';
    }
    setState(() {
      _setRir[key] = rir;
      // La base encontrada se aplica a todas las series que faltan.
      final last = rir >= 2 && rir < 4 ? ex.sets : set + 1;
      for (int s = set + 1; s <= last && s <= ex.sets; s++) {
        if (!_completedSets.contains(_setKey(idx, s))) _setWeight(idx, s, nextW, touched: true);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

    final completedExercises = <Map<String, dynamic>>[];
    for (int i = 0; i < widget.exercises.length; i++) {
      final e = widget.exercises[i];
      final logs = <WorkoutSet>[];
      for (int s = 1; s <= e.sets; s++) {
        final key = _setKey(i, s);
        if (!_completedSets.contains(key)) continue;
        logs.add(WorkoutSet(
          weightKg: _setWeights[key] ?? 0,
          reps: e.isTimed ? 0 : (_setReps[key] ?? _targetRepsFor(i)),
          seconds: e.isTimed ? _targetSecondsFor(i) : 0,
          rir: _setRir[key],
        ));
      }
      final maxWeight = logs.fold<double>(0, (m, l) => l.weightKg > m ? l.weightKg : m);
      completedExercises.add({
        'exerciseId': e.exerciseId,
        'exerciseName': e.exerciseName,
        'setsCompleted': logs.length,
        'repsCompleted': e.reps,
        'weightKg': maxWeight,
        'setLogs': logs.map((l) => l.toJson()).toList(),
        // Prescripción usada hoy (puede tener cambios aún no guardados en la rutina).
        'prescription': {
          'sets': e.sets,
          'reps': e.reps,
          if (e.repsMin != null && e.repsMax != null) 'repsMin': e.repsMin,
          if (e.repsMin != null && e.repsMax != null) 'repsMax': e.repsMax,
          'incrementKg': e.incrementKg,
        },
      });
    }

    setState(() => _savingWorkout = true);
    final gym = context.read<GymProvider>();
    await gym.logWorkout({
      'routineName': widget.routineName,
      if (widget.routineId != null && widget.routineId!.isNotEmpty) 'routineId': widget.routineId,
      'duration': _totalTimer.elapsed.inSeconds,
      'exercises': completedExercises,
    });
    if (mounted) setState(() => _savingWorkout = false);
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
    final gym = context.read<GymProvider>();
    final matched = gym.exercises.where((e) => e.id == ex.exerciseId);
    final imageUrl = matched.isNotEmpty ? matched.first.imageUrl : '';
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
          const SizedBox(height: 12),
          _buildTargetCard(_currentExerciseIndex),
        ],
      ),
    );
  }

  /// "Objetivo de hoy": peso, rango y condición para subir. Solo se reconstruye
  /// cuando cambia el progreso de este ejercicio.
  Widget _buildTargetCard(int idx) {
    final ex = widget.exercises[idx];
    return Selector<GymProvider, ExerciseProgress?>(
      selector: (_, g) => g.progressFor(ex.exerciseId),
      builder: (context, p, _) {
        final range = ex.repsMin != null && ex.repsMax != null ? '${ex.repsMin}-${ex.repsMax}' : ex.reps;
        final repsMax = ex.repsMax ?? int.tryParse(ex.reps.trim());
        final n = p?.next;
        String title;
        String? subtitle;
        String? hint;
        Color color = AppTheme.secondary;
        IconData icon = Icons.flag;

        if (ex.isTimed) {
          final secs = _targetSecondsFor(idx);
          title = '$secs s × ${ex.sets}';
          subtitle = 'Completa todas las series y sube a ${secs + 5} s';
        } else if (p == null || p.isCalibrating) {
          title = 'Calibrando peso base';
          subtitle = 'Elige un peso con el que llegues a ${ex.defaultTargetReps} reps y te queden unas 2. '
              'Tras cada serie te preguntamos cómo te fue.';
          color = AppTheme.tertiary;
          icon = Icons.tune;
        } else if (n != null && n.isBridge) {
          final heavy = List.generate(n.heavySets.clamp(0, ex.sets), (i) => i + 1);
          final light = List.generate(ex.sets - heavy.length, (i) => heavy.length + i + 1);
          String seriesTxt(List<int> l) =>
              l.length == 1 ? 'Serie ${l.first}' : 'Series ${l.sublist(0, l.length - 1).join(', ')} y ${l.last}';
          title = 'Puente hacia ${_fmtWeight(idx, n.weightKg)}';
          subtitle = '${seriesTxt(heavy)} con ${_fmtWeight(idx, n.weightKg)}'
              '${light.isNotEmpty ? ', ${seriesTxt(light).toLowerCase()} con ${_fmtWeight(idx, n.baseWeightKg)}' : ''}';
          icon = Icons.stairs;
        } else {
          final w = p.weightForSet(1);
          title = '${_fmtWeight(idx, w)} × $range';
          if (repsMax != null && ex.incrementKg > 0) {
            subtitle = 'Sube a ${_fmtWeight(idx, w + ex.incrementKg)} cuando logres ${ex.sets} × $repsMax';
          }
          hint = n?.message;
          if (n != null && n.isDeload) {
            color = AppTheme.error;
            icon = Icons.warning_amber_rounded;
          }
        }
        if (p != null && p.loadNote.isNotEmpty) hint = [hint, p.loadNote].whereType<String>().join(' · ');

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OBJETIVO DE HOY', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    const SizedBox(height: 2),
                    Text(title, style: AppTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTheme.bodySmall),
                    ],
                    if (hint != null && hint.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(hint, style: AppTheme.bodySmall.copyWith(color: color)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeightInput() {
    final key = _setKey(_currentExerciseIndex, _currentSet);
    final alreadyDone = _completedSets.contains(key);
    final idx = _currentExerciseIndex;
    final ex = _currentExercise;
    final currentWeight = _setWeights[key] ?? 0;
    final controller = _getWeightController(key, _fmtInput(idx, currentWeight));
    // Paso de +/-: el incremento del ejercicio en kg, 5 lb en libras.
    final step = _useLbs ? 5.0 : (ex.incrementKg > 0 ? ex.incrementKg : 2.5);

    if (alreadyDone) return const SizedBox.shrink();

    void applyDisplayValue(double display) {
      final val = display.clamp(0.0, 999.0).toDouble();
      setState(() {
        _setWeights[key] = _useLbs ? val * _kgPerLb : val;
        _touchedWeights.add(key);
        controller.text = val.toStringAsFixed(1);
      });
    }

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
                    onChanged: (v) {
                      final unit = v ? 'lb' : 'kg';
                      setState(() {
                        _unitByExercise[ex.exerciseId] = unit;
                        for (int s = 1; s <= ex.sets; s++) {
                          final k = _setKey(idx, s);
                          _weightControllers[k]?.text = _fmtInput(idx, _setWeights[k] ?? 0);
                        }
                      });
                      // La unidad se recuerda por ejercicio (solo visualización).
                      context.read<GymProvider>().updateProgress(
                        ex.exerciseId,
                        {'unit': unit, 'exerciseName': ex.exerciseName},
                      );
                    },
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
                    onPressed: () => applyDisplayValue(
                        (_useLbs ? currentWeight / _kgPerLb : currentWeight) - step),
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
                        // onChanged (no solo al enviar): si el usuario toca
                        // "Completar serie" con el teclado abierto, el peso no se pierde.
                        onChanged: (v) {
                          final parsed = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                          setState(() {
                            _setWeights[key] = _useLbs ? parsed * _kgPerLb : parsed;
                            _touchedWeights.add(key);
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
                    onPressed: () => applyDisplayValue(
                        (_useLbs ? currentWeight / _kgPerLb : currentWeight) + step),
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
                'PR actual: ${formatKg(_exercisePr!)}kg',
                style: AppTheme.bodySmall.copyWith(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 12),
          if (ex.isTimed)
            Text(
              'Objetivo: ${_targetSecondsFor(idx)} s',
              style: AppTheme.labelLarge,
              textAlign: TextAlign.center,
            )
          else
            _buildRepsSelector(key, idx),
        ],
      ),
    );
  }

  /// Repeticiones logradas en la serie actual; viene con el objetivo para que
  /// una serie normal siga siendo un solo toque.
  Widget _buildRepsSelector(String key, int idx) {
    final reps = _setReps[key] ?? _targetRepsFor(idx);
    void change(int delta) => setState(() => _setReps[key] = (reps + delta).clamp(0, 200));
    return Row(
      children: [
        Icon(Icons.repeat, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        Text('REPS LOGRADAS', style: AppTheme.labelLarge),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.remove, color: AppTheme.primary, size: 18),
          onPressed: reps > 0 ? () => change(-1) : null,
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$reps',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, color: AppTheme.primary, size: 18),
          onPressed: () => change(1),
        ),
      ],
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
                  child: SingleChildScrollView(
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
                        const SizedBox(height: 16),
                        _buildNextSession(),
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

  /// "Próxima sesión": qué hacer la próxima vez con cada ejercicio.
  Widget _buildNextSession() {
    if (_savingWorkout) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Selector<GymProvider, List<MapEntry<String, ProgressSuggestion>>>(
      selector: (_, g) => g.lastProgression,
      builder: (context, items, _) {
        if (items.isEmpty) return const SizedBox.shrink();
        final names = {for (final e in widget.exercises) e.exerciseId: e.exerciseName};
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PRÓXIMA SESIÓN', style: AppTheme.labelLarge.copyWith(color: AppTheme.secondary, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        switch (item.value.action) {
                          'increase' => Icons.trending_up,
                          'bridge' => Icons.stairs,
                          'decrease' || 'deload' => Icons.trending_down,
                          _ => Icons.trending_flat,
                        },
                        size: 18,
                        color: item.value.isDeload ? AppTheme.error : AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: '${(names[item.key] ?? '').isNotEmpty ? names[item.key] : 'Ejercicio'}: ',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            TextSpan(text: item.value.message, style: AppTheme.bodySmall),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
