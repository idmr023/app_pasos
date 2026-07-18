import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/gym_provider.dart';
import '../../models/exercise.dart';
import '../../models/routine.dart';
import '../../widgets/glass_card.dart';
import 'exercise_library_screen.dart';
import 'workout_screen.dart';

class RoutineBuilderScreen extends StatefulWidget {
  final Routine? editRoutine;

  const RoutineBuilderScreen({super.key, this.editRoutine});

  @override
  State<RoutineBuilderScreen> createState() => _RoutineBuilderScreenState();
}

class _RoutineBuilderScreenState extends State<RoutineBuilderScreen> {
  late TextEditingController _nameController;
  bool _isWarmup = false;
  List<RoutineExercise> _exercises = [];
  bool _isSaving = false;
  final Map<String, Exercise> _exerciseDetails = {};

  @override
  void initState() {
    super.initState();
    if (widget.editRoutine != null) {
      final r = widget.editRoutine!;
      _nameController = TextEditingController(text: r.name);
      _isWarmup = r.isWarmup;
      _exercises = r.exercises.map((e) => RoutineExercise(
        exerciseId: e.exerciseId,
        exercise: e.exercise,
        sets: e.sets,
        reps: e.reps,
        restTime: e.restTime,
        order: e.order,
      )).toList();
      for (final e in _exercises) {
        if (e.exercise != null) {
          _exerciseDetails[e.exerciseId] = e.exercise!;
        }
      }
    } else {
      _nameController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickExercises() async {
    final gym = context.read<GymProvider>();
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseLibraryScreen(
          selectionMode: true,
          selectedIds: _exercises.map((e) => e.exerciseId).toList(),
        ),
      ),
    );

    if (result == null) return;
    final allExercises = gym.exercises;
    final exerciseMap = {for (final e in allExercises) e.id: e};

    for (final id in result) {
      final exists = _exercises.any((e) => e.exerciseId == id);
      if (!exists) {
        final ex = exerciseMap[id];
        _exercises.add(RoutineExercise(
          exerciseId: id,
          exercise: ex,
          sets: ex?.defaultSets ?? 3,
          reps: ex?.defaultReps ?? '10',
          restTime: ex?.restTime ?? 60,
          order: _exercises.length,
        ));
        if (ex != null) _exerciseDetails[id] = ex;
      }
    }

    _exercises.removeWhere((e) => !result.contains(e.exerciseId));
    _exercises.asMap().forEach((i, e) => e.order = i);
    setState(() {});
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _exercises.isEmpty) return;

    setState(() => _isSaving = true);

    final body = {
      'name': name,
      'isWarmup': _isWarmup,
      'exercises': _exercises.map((e) => e.toJson()).toList(),
    };

    final gym = context.read<GymProvider>();
    bool success;
    if (widget.editRoutine != null) {
      success = await gym.createRoutine(body);
    } else {
      success = await gym.createRoutine(body);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(gym.error ?? 'Error al guardar'), backgroundColor: AppTheme.error),
      );
    }
  }

  void _startWorkout() {
    if (_exercises.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutScreen(
          routineName: _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : 'Rutina',
          exercises: _exercises,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      _buildNameField(),
                      const SizedBox(height: 16),
                      _buildWarmupToggle(),
                      const SizedBox(height: 16),
                      _buildExercisePicker(),
                      const SizedBox(height: 16),
                      if (_exercises.isNotEmpty) _buildExerciseList(),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            widget.editRoutine != null ? 'EDITAR RUTINA' : 'NUEVA RUTINA',
            style: AppTheme.titleLarge.copyWith(letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: TextFormField(
        controller: _nameController,
        style: AppTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: 'Nombre de la rutina',
          hintText: 'Ej: Push Pull, Full Body...',
          prefixIcon: const Icon(Icons.edit, color: AppTheme.primary, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }

  Widget _buildWarmupToggle() {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.whatshot, color: _isWarmup ? AppTheme.tertiary : AppTheme.darkGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rutina de calentamiento', style: AppTheme.bodyLarge),
                Text('Aparecerá en la sección de warm-up', style: AppTheme.bodySmall),
              ],
            ),
          ),
          Switch(
            value: _isWarmup,
            activeTrackColor: AppTheme.tertiary.withValues(alpha: 0.4),
            activeThumbColor: AppTheme.tertiary,
            onChanged: (v) => setState(() => _isWarmup = v),
          ),
        ],
      ),
    );
  }

  Widget _buildExercisePicker() {
    return GlassCard(
      width: double.infinity,
      onTap: _pickExercises,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _exercises.isEmpty ? 'Seleccionar ejercicios' : '${_exercises.length} ejercicios seleccionados',
              style: AppTheme.bodyLarge,
            ),
          ),
          Icon(Icons.chevron_right, color: AppTheme.darkGrey),
        ],
      ),
    );
  }

  Widget _buildExerciseList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _exercises.length,
      onReorderItem: (oldI, newI) {
        setState(() {
          final item = _exercises.removeAt(oldI);
          _exercises.insert(newI, item);
          _exercises.asMap().forEach((i, e) => e.order = i);
        });
      },
      itemBuilder: (ctx, i) {
        final ex = _exercises[i];
        final details = _exerciseDetails[ex.exerciseId];

        return GlassCard(
          key: ValueKey(ex.exerciseId + ex.order.toString()),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.drag_handle, color: AppTheme.darkGrey, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          details?.displayName ?? 'Ejercicio',
                          style: AppTheme.titleMedium,
                        ),
                        Text(
                          details?.category.toUpperCase() ?? '',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.error, size: 18),
                      onPressed: () {
                        setState(() => _exercises.removeAt(i));
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSmallInput('Series', ex.sets.toString(), (v) {
                      final parsed = int.tryParse(v) ?? ex.sets;
                      ex.sets = parsed.clamp(3, 5);
                      setState(() {});
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRepsInput(ex),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSmallInput('Descanso', '${ex.restTime}s', (v) {
                      ex.restTime = int.tryParse(v.replaceAll('s', '')) ?? ex.restTime;
                      setState(() {});
                    }),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRepsInput(RoutineExercise ex) {
    const options = ['8', '10', '12', '15', '20', '30s', '45s', '60s', 'Al fallo'];
    final isCustom = !options.contains(ex.reps);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text('Reps', style: TextStyle(fontSize: 9, color: AppTheme.darkGrey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          isCustom
              ? TextFormField(
                  initialValue: ex.reps,
                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onFieldSubmitted: (v) {
                    ex.reps = v;
                    setState(() {});
                  },
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: ex.reps,
                    isDense: true,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                    items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        ex.reps = v;
                        setState(() {});
                      }
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSmallInput(String label, String value, Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: AppTheme.darkGrey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          TextFormField(
            initialValue: value,
            style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onFieldSubmitted: onChanged,
            onEditingComplete: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
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
              if (_exercises.isNotEmpty)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _startWorkout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.secondary,
                      side: BorderSide(color: AppTheme.secondary.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow, size: 20),
                          const SizedBox(width: 6),
                          const Text('INICIAR', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_exercises.isNotEmpty) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}