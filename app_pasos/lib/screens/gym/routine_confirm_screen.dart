import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/exercise.dart';
import '../../providers/gym_provider.dart';
import '../../widgets/glass_card.dart';

class RoutineConfirmScreen extends StatelessWidget {
  final String routineName;
  final List<Exercise> selectedExercises;
  final int globalSets;
  final String globalReps;
  final int globalRestTime;

  const RoutineConfirmScreen({
    super.key,
    required this.routineName,
    required this.selectedExercises,
    required this.globalSets,
    required this.globalReps,
    required this.globalRestTime,
  });

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
              _buildTopBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStepIndicator(3),
                      const SizedBox(height: 20),
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      _buildExerciseList(),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int current) {
    return Row(
      children: [
        _stepDot(1, 'Elegir', current > 1),
        _stepLine(current > 1),
        _stepDot(2, 'Configurar', current > 2),
        _stepLine(current > 2),
        _stepDot(3, 'Confirmar', false),
      ],
    );
  }

  Widget _stepDot(int number, String label, bool done) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? AppTheme.tertiary
                  : number == 3
                      ? AppTheme.primary
                      : AppTheme.darkGrey.withValues(alpha: 0.3),
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: number == 3 ? AppTheme.primary : AppTheme.darkGrey,
              fontWeight: number == 3 ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLine(bool done) {
    return Container(
      height: 2,
      width: 32,
      color: done ? AppTheme.tertiary : AppTheme.darkGrey.withValues(alpha: 0.3),
    );
  }

  Widget _buildTopBar(BuildContext context) {
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
            'CONFIRMAR RUTINA',
            style: AppTheme.titleLarge.copyWith(letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fitness_center, size: 20, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(routineName, style: AppTheme.titleMedium),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),
          Row(
            children: [
              _summaryItem('Ejercicios', '${selectedExercises.length}'),
              _summaryItem('Series', '$globalSets'),
              _summaryItem('Reps', globalReps),
              _summaryItem('Descanso', '${globalRestTime}s'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.primary)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.darkGrey)),
        ],
      ),
    );
  }

  Widget _buildExerciseList() {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EJERCICIOS', style: AppTheme.labelLarge),
          const SizedBox(height: 12),
          ...selectedExercises.asMap().entries.map((entry) {
            final i = entry.key;
            final ex = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: i < selectedExercises.length - 1
                    ? const Border(bottom: BorderSide(color: Colors.white12))
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w700))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(ex.displayName, style: AppTheme.bodyMedium),
                  ),
                  Text(
                    '${globalSets}x$globalReps',
                    style: const TextStyle(color: AppTheme.darkGrey, fontSize: 13),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _save(context),
            icon: const Icon(Icons.save),
            label: const Text('GUARDAR RUTINA', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final gym = context.read<GymProvider>();

    final body = {
      'name': routineName,
      'exercises': selectedExercises.asMap().entries.map((entry) => {
        'exerciseId': entry.value.id,
        'exerciseName': entry.value.displayName,
        'name': entry.value.displayName,
        'sets': globalSets,
        'reps': globalReps,
        'restTime': globalRestTime,
        'order': entry.key,
      }).toList(),
    };

    final success = await gym.createRoutine(body);
    if (!context.mounted) return;

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(gym.error ?? 'Error al guardar'), backgroundColor: AppTheme.error),
      );
    }
  }
}
