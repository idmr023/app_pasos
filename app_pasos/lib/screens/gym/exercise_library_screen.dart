import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/gym_provider.dart';
import '../../models/exercise.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/exercise_image.dart';
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
  final ScrollController _scrollController = ScrollController();

  final _categories = [
    {'key': null, 'label': 'Todos'},
    {'key': 'strength', 'label': 'Fuerza'},
    {'key': 'cardio', 'label': 'Cardio'},
  ];

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedIds ?? []);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GymProvider>().loadExercises(reset: true);
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final gym = context.read<GymProvider>();
      if (gym.hasMore && !gym.isLoading) {
        gym.loadExercises(
          category: _selectedCategory,
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
        );
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
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
                child: gym.isLoading && gym.exercises.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : gym.error != null && gym.exercises.isEmpty
                        ? _buildErrorState(gym)
                        : _buildGrid(gym),
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
                      context.read<GymProvider>().loadExercises(category: _selectedCategory, reset: true);
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
                reset: true,
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
                  reset: true,
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
              onPressed: () => context.read<GymProvider>().loadExercises(reset: true),
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

  Widget _buildGrid(GymProvider gym) {
    final exercises = gym.exercises;
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
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: exercises.length + (gym.hasMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == exercises.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          );
        }
        return _ExerciseCard(
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
        );
      },
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
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ExerciseImage(
                    exercise: ex,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    fallbackIcon: _placeholderIconFor(ex.category),
                    fallbackColor: _placeholderColorFor(ex.category),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex.displayName,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${ex.defaultSets}×${ex.defaultReps}',
                        style: TextStyle(color: AppTheme.grey.withValues(alpha: 0.7), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (selectionMode && isSelected)
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
          ],
        ),
      ),
    );
  }

  IconData _placeholderIconFor(String category) {
    switch (category) {
      case 'cardio':
        return Icons.favorite;
      default:
        return Icons.fitness_center;
    }
  }

  Color _placeholderColorFor(String category) {
    switch (category) {
      case 'cardio':
        return AppTheme.error;
      default:
        return AppTheme.secondary;
    }
  }
}
