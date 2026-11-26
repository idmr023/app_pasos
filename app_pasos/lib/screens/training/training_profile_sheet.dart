import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/training.dart';
import '../../providers/training_provider.dart';
import '../../widgets/loading_states.dart';
import 'training_widgets.dart';

/// Hoja inferior: FC máx/reposo, sesiones por semana y objetivo de carrera.
class TrainingProfileSheet extends StatefulWidget {
  const TrainingProfileSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => const TrainingProfileSheet(),
      );

  @override
  State<TrainingProfileSheet> createState() => _TrainingProfileSheetState();
}

class _TrainingProfileSheetState extends State<TrainingProfileSheet> {
  static const _distances = [(5.0, '5K'), (10.0, '10K'), (21.0975, 'Media'), (42.195, 'Maratón')];

  late final TextEditingController _maxHr;
  late final TextEditingController _restHr;
  late final TextEditingController _goalName;
  late final TextEditingController _goalTime;
  late final TextEditingController _goalKm;
  late int _sessions;
  DateTime? _goalDate;
  bool _hasGoal = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<TrainingProvider>().profile;
    _maxHr = TextEditingController(text: p.maxHeartRate?.toString() ?? '');
    _restHr = TextEditingController(text: p.restingHeartRate?.toString() ?? '');
    _sessions = p.weeklySessions;
    final g = p.goal;
    _hasGoal = g != null;
    _goalName = TextEditingController(text: g?.name ?? '');
    _goalKm = TextEditingController(text: g?.distanceKm?.toString() ?? '');
    _goalTime = TextEditingController(text: g?.targetTimeSec != null ? formatDuration(g!.targetTimeSec) : '');
    _goalDate = g?.date;
  }

  @override
  void dispose() {
    for (final c in [_maxHr, _restHr, _goalName, _goalTime, _goalKm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final maxHr = _maxHr.text.trim().isEmpty ? null : int.tryParse(_maxHr.text.trim());
    final restHr = _restHr.text.trim().isEmpty ? null : int.tryParse(_restHr.text.trim());
    Map<String, dynamic>? goal;
    if (_hasGoal) {
      final km = double.tryParse(_goalKm.text.replaceAll(',', '.'));
      if (km == null || km <= 0) {
        _snack('Indica la distancia del objetivo');
        return;
      }
      final time = _goalTime.text.trim().isEmpty ? null : parseDurationInput(_goalTime.text);
      if (_goalTime.text.trim().isNotEmpty && time == null) {
        _snack('Tiempo objetivo: usa h:mm:ss o mm:ss');
        return;
      }
      goal = TrainingGoal(name: _goalName.text.trim(), distanceKm: km, targetTimeSec: time, date: _goalDate).toJson();
    }

    setState(() => _saving = true);
    final error = await context.read<TrainingProvider>().updateProfile({
      'maxHeartRate': maxHr,
      'restingHeartRate': restHr,
      'weeklySessions': _sessions,
      'goal': goal,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      _snack(error);
    } else {
      Navigator.pop(context);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.error));
  }

  InputDecoration _dec(String label, {String? hint, String? suffix}) =>
      InputDecoration(labelText: label, hintText: hint, suffixText: suffix, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Colors.white);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.darkGrey, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text('Perfil de entrenamiento', style: AppTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Tu FC máxima define las zonas y la carga. Si no la sabes, déjala vacía y usaremos la más alta registrada.',
                style: AppTheme.bodySmall),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(controller: _maxHr, style: style, keyboardType: TextInputType.number, decoration: _dec('FC máxima', suffix: 'ppm')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(controller: _restHr, style: style, keyboardType: TextInputType.number, decoration: _dec('FC en reposo', suffix: 'ppm')),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Días de entrenamiento por semana: $_sessions', style: AppTheme.bodyMedium.copyWith(color: AppTheme.white)),
            Slider(
              value: _sessions.toDouble(),
              min: 2,
              max: 7,
              divisions: 5,
              label: '$_sessions',
              onChanged: (v) => setState(() => _sessions = v.round()),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _hasGoal,
              onChanged: (v) => setState(() => _hasGoal = v),
              title: Text('Tengo una carrera objetivo', style: AppTheme.bodyMedium.copyWith(color: AppTheme.white)),
            ),
            if (_hasGoal) ...[
              TextField(controller: _goalName, style: style, decoration: _dec('Nombre', hint: 'Ej: 10K de Lima')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: _distances.map((d) {
                  final selected = double.tryParse(_goalKm.text) == d.$1;
                  return ChoiceChip(
                    label: Text(d.$2),
                    selected: selected,
                    onSelected: (_) => setState(() => _goalKm.text = d.$1.toString()),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _goalKm,
                      style: style,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _dec('Distancia', suffix: 'km'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(controller: _goalTime, style: style, decoration: _dec('Tiempo objetivo', hint: 'h:mm:ss')),
                  ),
                ],
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event, color: AppTheme.primary),
                title: Text(
                  _goalDate == null ? 'Fecha de la carrera' : '${formatShortDate(_goalDate!)} ${_goalDate!.year}',
                  style: style,
                ),
                trailing: const Icon(Icons.edit, size: 18, color: AppTheme.grey),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _goalDate != null && _goalDate!.isAfter(DateTime.now())
                        ? _goalDate!
                        : DateTime.now().add(const Duration(days: 60)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (d != null) setState(() => _goalDate = d);
                },
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, minimumSize: const Size.fromHeight(48)),
              child: _saving ? const InlineSpinner() : const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
