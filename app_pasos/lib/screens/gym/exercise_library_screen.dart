import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../providers/gym_provider.dart';
import '../../models/exercise.dart';
import '../../widgets/glass_card.dart';
import 'exercise_detail_sheet.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  final bool selectionMode;
  final List<String>? selectedIds;
  final ValueChanged<List<String>>? onSelectionChanged;

  const ExerciseLibraryScreen({
    super.key,
    this.selectionMode = false,
    this.selectedIds,
    this.onSelectionChanged,
  });

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  String? _selectedCategory;
  Set<String> _selected = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  final _categories = [
    {'key': null, 'label': 'Todos'},
    {'key': 'warmup', 'label': 'Calentamiento'},
    {'key': 'strength', 'label': 'Fuerza'},
    {'key': 'cardio', 'label': 'Cardio'},
    {'key': 'flexibility', 'label': 'Flexibilidad'},
  ];

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedIds ?? []);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GymProvider>().loadExercises();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();

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
              _buildSearchBar(),
              _buildCategoryFilter(),
              Expanded(
                child: gym.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : gym.error != null
                        ? _buildErrorState(gym)
                        : _buildGrid(gym.exercises),
              ),
              if (widget.selectionMode)
                _buildSelectionBar(),
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
            onPressed: () => Navigator.pop(context, widget.selectionMode ? _selected.toList() : null),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.selectionMode ? 'SELECCIONAR EJERCICIOS' : 'EJERCICIOS',
              style: AppTheme.titleLarge.copyWith(letterSpacing: 2),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassCard(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        borderRadius: 16,
        child: TextField(
          controller: _searchController,
          style: AppTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Buscar ejercicios...',
            prefixIcon: const Icon(Icons.search, color: AppTheme.primary, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: AppTheme.darkGrey, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      context.read<GymProvider>().loadExercises(category: _selectedCategory);
                    },
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (v) {
            setState(() => _searchQuery = v);
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), () {
              context.read<GymProvider>().loadExercises(
                category: _selectedCategory,
                search: v.isNotEmpty ? v : null,
              );
            });
          },
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedCategory = cat['key']);
                context.read<GymProvider>().loadExercises(
                  category: cat['key'],
                  search: _searchQuery.isNotEmpty ? _searchQuery : null,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Text(
                  cat['label'] as String,
                  style: TextStyle(
                    color: isSelected ? AppTheme.primary : AppTheme.grey,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildErrorState(GymProvider gym) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: 16),
            Text('Error al cargar ejercicios', style: AppTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(gym.error!, style: AppTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.read<GymProvider>().loadExercises(),
              icon: const Icon(Icons.refresh),
              label: const Text('REINTENTAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<Exercise> exercises) {
    if (exercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: AppTheme.darkGrey),
            const SizedBox(height: 16),
            Text('No hay ejercicios', style: AppTheme.bodyMedium),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: exercises.length,
      itemBuilder: (ctx, i) => _ExerciseCard(
        ex: exercises[i],
        isSelected: _selected.contains(exercises[i].id),
        selectionMode: widget.selectionMode,
        onTap: () {
          if (widget.selectionMode) {
            setState(() {
              final id = exercises[i].id;
              if (_selected.contains(id)) {
                _selected.remove(id);
              } else {
                _selected.add(id);
              }
            });
          } else {
            ExerciseDetailSheet.show(context, exercises[i]);
          }
        },
      ),
    );
  }

  Widget _buildSelectionBar() {
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
          child: ElevatedButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, _selected.toList()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              'SELECCIONAR (${_selected.length})',
              style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise ex;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.ex,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderColor: isSelected ? AppTheme.primary : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      color: AppTheme.surface.withValues(alpha: 0.3),
                    ),
                    child: ex.imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            child: CachedNetworkImage(
                              imageUrl: ex.imageUrl,
                              fit: BoxFit.contain,
                              placeholder: (_, __) => Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              errorWidget: (_, __, ___) => _placeholderIcon,
                            ),
                          )
                        : _placeholderIcon,
                  ),
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, size: 16, color: Colors.white),
                      ),
                    ),
                  if (!selectionMode)
                    Selector<GymProvider, double>(
                      selector: (_, g) => g.getPrForExercise(ex.id),
                      builder: (_, pr, __) {
                        if (pr <= 0) return const SizedBox.shrink();
                        return Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.gold.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events, size: 10, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  '${pr.toInt()}kg',
                                  style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          '${ex.defaultSets}x${ex.defaultReps}',
                          style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        if (ex.videoUrl.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.play_circle_outline, size: 12, color: AppTheme.tertiary),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget get _placeholderIcon {
    IconData icon;
    switch (ex.category) {
      case 'warmup':
        icon = Icons.whatshot;
        break;
      case 'cardio':
        icon = Icons.directions_run;
        break;
      case 'flexibility':
        icon = Icons.self_improvement;
        break;
      default:
        icon = Icons.fitness_center;
    }
    return Center(
      child: Icon(icon, size: 40, color: AppTheme.darkGrey),
    );
  }
}
