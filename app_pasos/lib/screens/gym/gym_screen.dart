import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gym_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/neon_button.dart';
import 'exercise_library_screen.dart';
import 'routine_config_screen.dart';
import 'routine_confirm_screen.dart';
import 'routine_builder_screen.dart';

class GymScreen extends StatefulWidget {
  const GymScreen({super.key});

  @override
  State<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends State<GymScreen> {
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    if (_hasLoaded) return;
    _hasLoaded = true;
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    final gym = context.read<GymProvider>();
    gym.setToken(token);
    gym.loadExercises(reset: true);
    gym.loadRoutines();
    gym.loadPersonalRecords();
    gym.loadWeightAchievements();
    gym.loadStreak().then((_) => gym.loadQuote());
  }

  Future<void> _createRoutineFlow(BuildContext context) async {
    final selectedIds = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const ExerciseLibraryScreen(selectionMode: true),
      ),
    );
    if (selectedIds == null || selectedIds.isEmpty || !mounted) return;

    final gym = context.read<GymProvider>();
    final selectedExercises = gym.exercises
        .where((e) => selectedIds.contains(e.id))
        .toList();
    if (selectedExercises.isEmpty) return;

    final config = await Navigator.push<RoutineConfigResult>(
      context,
      MaterialPageRoute(
        builder: (_) => RoutineConfigScreen(selectedExercises: selectedExercises),
      ),
    );
    if (config == null || !mounted) return;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RoutineConfirmScreen(
          routineName: config.name,
          selectedExercises: selectedExercises,
          globalSets: config.sets,
          globalReps: config.reps,
          globalRestTime: config.restTime,
        ),
      ),
    );
    if (saved == true && mounted) _loadData();
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
            if (gym.currentQuote != null)
              SliverToBoxAdapter(child: _buildQuoteBanner(gym)),
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

  Widget _buildQuoteBanner(GymProvider gym) {
    final quote = gym.currentQuote!;
    final type = quote['type'] as String? ?? 'streak';
    final isAnniversary = type == 'anniversary';
    final color = isAnniversary ? AppTheme.gold : AppTheme.tertiary;
    final icon = isAnniversary ? Icons.celebration : Icons.bolt;
    final label = isAnniversary ? 'ANIVERSARIO' : 'RACHA';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  quote['text'] as String? ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
              onPressed: () => _createRoutineFlow(context),
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
                Text(routine.name, style: AppTheme.titleMedium, overflow: TextOverflow.ellipsis),
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