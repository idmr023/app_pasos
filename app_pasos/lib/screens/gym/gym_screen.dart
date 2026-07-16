import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gym_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/neon_button.dart';
import 'exercise_library_screen.dart';
import 'routine_builder_screen.dart';

class GymScreen extends StatefulWidget {
  const GymScreen({super.key});

  @override
  State<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends State<GymScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    final gym = context.read<GymProvider>();
    gym.setToken(token);
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(gym)),
            SliverToBoxAdapter(child: _buildStreakCard(gym)),
            SliverToBoxAdapter(child: _buildActions()),
            SliverToBoxAdapter(child: _buildSectionTitle('MIS RUTINAS')),
            if (gym.isLoading)
              const SliverToBoxAdapter(child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              ))
            else if (gym.routines.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyRoutines())
            else
              SliverToBoxAdapter(child: _buildRoutinesList(gym)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(GymProvider gym) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: Text('GIMNASIO', style: AppTheme.titleLarge.copyWith(letterSpacing: 2)),
    );
  }

  Widget _buildStreakCard(GymProvider gym) {
    return GlassCard(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(Icons.local_fire_department,
            size: 40,
            color: gym.streak > 0 ? AppTheme.primary : AppTheme.darkGrey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gym.streak > 0
                      ? '${gym.streak} ${gym.streak == 1 ? 'semana' : 'semanas'} seguidas'
                      : 'Sin racha aún',
                  style: AppTheme.titleMedium,
                ),
                Text(
                  gym.currentWeekChecked
                      ? '✓ Esta semana ya entrenaste'
                      : 'Entrena esta semana para mantener tu racha',
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Expanded(
            child: NeonButton(
              label: 'NUEVA RUTINA',
              icon: Icons.add,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RoutineBuilderScreen()),
              ).then((_) => _loadData()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: NeonButton(
              label: 'EJERCICIOS',
              icon: Icons.search,
              color: AppTheme.tertiary,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: AppTheme.labelLarge),
    );
  }

  Widget _buildEmptyRoutines() {
    return GlassCard(
      width: double.infinity,
      child: Column(
        children: [
          const Icon(Icons.fitness_center_outlined, size: 48, color: AppTheme.darkGrey),
          const SizedBox(height: 16),
          Text('No tienes rutinas', style: AppTheme.bodyLarge),
          const SizedBox(height: 4),
          Text('Crea tu primera rutina', style: AppTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildRoutinesList(GymProvider gym) {
    return Column(
      children: gym.routines.map((r) => _buildRoutineCard(r)).toList(),
    );
  }

  Widget _buildRoutineCard(routine) {
    final exerciseCount = routine.exercises.length;
    return GlassCard(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoutineBuilderScreen(editRoutine: routine),
        ),
        ).then((_) => _loadData()),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: routine.isWarmup
                  ? AppTheme.tertiary.withValues(alpha: 0.1)
                  : AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              routine.isWarmup ? Icons.whatshot : Icons.fitness_center,
              color: routine.isWarmup ? AppTheme.tertiary : AppTheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(routine.name, style: AppTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '$exerciseCount ejercicios${routine.isWarmup ? ' · Calentamiento' : ''}',
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppTheme.darkGrey),
        ],
      ),
    );
  }
}