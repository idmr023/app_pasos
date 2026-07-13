import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../config/theme.dart';

class StepInputDialog extends StatefulWidget {
  final DateTime date;

  const StepInputDialog({super.key, required this.date});

  @override
  State<StepInputDialog> createState() => _StepInputDialogState();
}

class _StepInputDialogState extends State<StepInputDialog>
    with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  int _quickAmount = 0;

  final List<int> _quickOptions = [0, 1000, 3000, 5000, 8000, 10000, 15000];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dayName = _getDayName(widget.date.weekday);
    final dateStr = '${widget.date.day} de ${_getMonthName(widget.date.month)}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withValues(alpha: 0.1),
                  ),
                  child: const Icon(Icons.directions_walk, size: 36, color: AppTheme.primary),
                ),
                const SizedBox(height: 12),
                Text('$dayName, $dateStr', style: AppTheme.titleMedium),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: AppTheme.counterLarge.copyWith(fontSize: 48),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: AppTheme.counterLarge.copyWith(fontSize: 48, color: Colors.white.withValues(alpha: 0.08)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _quickAmount = int.tryParse(value) ?? 0);
                  },
                ),
                const SizedBox(height: 20),
                Text('Carga rápida', style: AppTheme.bodySmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickOptions.map((amount) {
                    final isSelected = _quickAmount == amount;
                    final icon = _getQuickIcon(amount);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _quickAmount = amount;
                          _controller.text = amount > 0 ? '$amount' : '';
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, size: 14, color: isSelected ? Colors.white : AppTheme.darkGrey),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              amount >= 1000 ? '${amount ~/ 1000}K' : '$amount',
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.grey,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final steps = int.tryParse(_controller.text) ?? 0;
                      Navigator.of(context).pop(steps);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('GUARDAR PASOS', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData? _getQuickIcon(int amount) {
    switch (amount) {
      case 1000: return Icons.directions_walk;
      case 3000: return Icons.directions_walk;
      case 5000: return Icons.run_circle_outlined;
      case 8000: return Icons.run_circle;
      case 10000: return Icons.emoji_events;
      case 15000: return Icons.local_fire_department;
      default: return null;
    }
  }

  String _getDayName(int weekday) {
    const days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                     'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return months[month - 1];
  }
}
