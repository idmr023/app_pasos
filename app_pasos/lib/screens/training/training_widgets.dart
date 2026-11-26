import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/training.dart';

const Color stravaOrange = Color(0xFFFC4C02);

Color sessionTypeColor(String type) {
  switch (type) {
    case 'recovery':
      return const Color(0xFF64B5F6);
    case 'easy':
      return AppTheme.tertiary;
    case 'long':
      return const Color(0xFF8B5CF6);
    case 'tempo':
      return AppTheme.gold;
    case 'intervals':
      return AppTheme.secondary;
    case 'race':
      return AppTheme.error;
    default:
      return AppTheme.grey;
  }
}

IconData sportIcon(String sport) {
  switch (sport) {
    case 'ride':
      return Icons.directions_bike;
    case 'walk':
      return Icons.directions_walk;
    case 'hike':
      return Icons.terrain;
    case 'swim':
      return Icons.pool;
    case 'trail':
      return Icons.landscape;
    case 'run':
      return Icons.directions_run;
    default:
      return Icons.fitness_center;
  }
}

class SessionTypeChip extends StatelessWidget {
  final String type;
  const SessionTypeChip(this.type, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = sessionTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        sessionTypeLabels[type] ?? type,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class InsightTile extends StatelessWidget {
  final TrainingInsight insight;
  const InsightTile(this.insight, {super.key});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (insight.level) {
      'good' => (Icons.check_circle, AppTheme.tertiary),
      'warn' => (Icons.warning_amber_rounded, AppTheme.gold),
      _ => (Icons.info_outline, AppTheme.primary),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(insight.text, style: AppTheme.bodyMedium.copyWith(color: AppTheme.white))),
        ],
      ),
    );
  }
}

class StatCell extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final Color? color;
  const StatCell({super.key, required this.label, required this.value, this.hint, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
        const SizedBox(height: 2),
        Text(value, style: AppTheme.titleLarge.copyWith(color: color ?? AppTheme.white)),
        if (hint != null) Text(hint!, style: AppTheme.bodySmall),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AppTheme.titleMedium)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Barras de distribución de zonas Z1–Z5.
class ZoneBars extends StatelessWidget {
  final List<int> percent;
  const ZoneBars(this.percent, {super.key});

  static const _colors = [
    Color(0xFF64B5F6),
    AppTheme.tertiary,
    AppTheme.gold,
    AppTheme.secondary,
    AppTheme.error,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(5, (i) {
        final p = i < percent.length ? percent[i] : 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(width: 28, child: Text('Z${i + 1}', style: AppTheme.bodySmall.copyWith(color: AppTheme.grey))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: p / 100,
                    minHeight: 10,
                    backgroundColor: AppTheme.surfaceAlt,
                    color: _colors[i],
                  ),
                ),
              ),
              SizedBox(width: 44, child: Text('$p%', textAlign: TextAlign.right, style: AppTheme.bodySmall.copyWith(color: AppTheme.white))),
            ],
          ),
        );
      }),
    );
  }
}

String formatShortDate(DateTime d) {
  const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  return '${d.day} ${months[d.month - 1]}';
}

/// Parsea "h:mm:ss", "mm:ss" o minutos sueltos → segundos.
int? parseDurationInput(String raw) {
  final parts = raw.trim().split(':').map((p) => int.tryParse(p.trim())).toList();
  if (parts.isEmpty || parts.any((p) => p == null || p < 0)) return null;
  final v = parts.cast<int>();
  if (v.length == 1) return v[0] * 60;
  if (v.length == 2) return v[0] * 60 + v[1];
  if (v.length == 3) return v[0] * 3600 + v[1] * 60 + v[2];
  return null;
}
