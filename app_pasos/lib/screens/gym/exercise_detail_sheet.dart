import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../config/theme.dart';
import '../../models/exercise.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/exercise_image.dart';

class ExerciseDetailSheet extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailSheet({super.key, required this.exercise});

  static void show(BuildContext context, Exercise exercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExerciseDetailSheet(exercise: exercise),
    );
  }

  @override
  State<ExerciseDetailSheet> createState() => _ExerciseDetailSheetState();
}

class _ExerciseDetailSheetState extends State<ExerciseDetailSheet> {
  YoutubePlayerController? _youtubeController;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() {
    final videoUrl = widget.exercise.videoUrl;
    if (videoUrl.isEmpty) return;

    String? videoId;
    if (videoUrl.contains('youtube.com/watch?v=')) {
      videoId = videoUrl.split('v=').last.split('&').first;
    } else if (videoUrl.contains('youtu.be/')) {
      videoId = videoUrl.split('youtu.be/').last.split('?').first;
    } else if (videoUrl.contains('youtube.com/embed/')) {
      videoId = videoUrl.split('embed/').last.split('?').first;
    }

    if (videoId != null && videoId.isNotEmpty) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          controlsVisibleAtStart: true,
        ),
      );
      setState(() => _videoReady = true);
    }
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'warmup': return 'Calentamiento';
      case 'strength': return 'Fuerza';
      case 'cardio': return 'Cardio';
      case 'flexibility': return 'Flexibilidad';
      default: return cat;
    }
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'warmup': return AppTheme.tertiary;
      case 'strength': return AppTheme.primary;
      case 'cardio': return AppTheme.secondary;
      case 'flexibility': return AppTheme.gold;
      default: return AppTheme.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E293B), AppTheme.background],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 1.0,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHandle(),
                _buildImage(ex),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(ex),
                      const SizedBox(height: 16),
                      _buildInfoChips(ex),
                      if (ex.description.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildDescription(ex),
                      ],
                      if (_videoReady) ...[
                        const SizedBox(height: 20),
                        _buildVideoSection(),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildImage(Exercise ex) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppTheme.surface.withValues(alpha: 0.3),
      ),
      child: ExerciseImage(
        exercise: ex,
        fit: BoxFit.contain,
        width: double.infinity,
        height: 220,
        borderRadius: BorderRadius.circular(20),
        fallbackIcon: _placeholderIconFor(ex.category),
        fallbackColor: AppTheme.darkGrey,
      ),
    );
  }

  IconData _placeholderIconFor(String category) {
    switch (category) {
      case 'warmup': return Icons.whatshot;
      case 'cardio': return Icons.directions_run;
      case 'flexibility': return Icons.self_improvement;
      default: return Icons.fitness_center;
    }
  }

  Widget _buildHeader(Exercise ex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ex.displayName,
          style: AppTheme.headlineMedium.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildBadge(_categoryLabel(ex.category), _categoryColor(ex.category)),
            if (ex.difficulty.isNotEmpty) ...[
              const SizedBox(width: 8),
              _buildBadge(ex.difficulty, AppTheme.gold),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildInfoChips(Exercise ex) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (ex.muscle.isNotEmpty)
            _buildChip(Icons.fitness_center, ex.muscle),
          if (ex.equipment.isNotEmpty) ...[
            const SizedBox(width: 12),
            _buildChip(Icons.build, ex.equipment),
          ],
          const SizedBox(width: 12),
          _buildChip(Icons.repeat, '${ex.defaultSets}x${ex.defaultReps}'),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(Exercise ex) {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DESCRIPCIÓN', style: AppTheme.labelLarge),
          const SizedBox(height: 8),
          Text(ex.displayDescription, style: AppTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildVideoSection() {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_fill, color: AppTheme.tertiary, size: 20),
              const SizedBox(width: 8),
              Text('VIDEO DEMOSTRATIVO', style: AppTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: YoutubePlayerBuilder(
              player: YoutubePlayer(
                controller: _youtubeController!,
                showVideoProgressIndicator: true,
                progressIndicatorColor: AppTheme.primary,
                progressColors: const ProgressBarColors(
                  playedColor: AppTheme.primary,
                  handleColor: AppTheme.primary,
                ),
              ),
              builder: (context, player) {
                return Column(
                  children: [
                    player,
                    const SizedBox(height: 8),
                    Text(
                      'Toca play para ver el video',
                      style: AppTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
