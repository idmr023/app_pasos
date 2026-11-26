import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/training.dart';
import '../../providers/training_provider.dart';
import '../../widgets/loading_states.dart';
import 'training_widgets.dart';

/// Registro manual de una sesión (cinta, reloj sin Strava, otro deporte…).
class TrainingLogScreen extends StatefulWidget {
  const TrainingLogScreen({super.key});

  @override
  State<TrainingLogScreen> createState() => _TrainingLogScreenState();
}

class _TrainingLogScreenState extends State<TrainingLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _distance = TextEditingController();
  final _duration = TextEditingController();
  final _avgHr = TextEditingController();
  final _maxHr = TextEditingController();
  final _elevation = TextEditingController();
  final _notes = TextEditingController();

  String _sport = 'run';
  String _type = 'auto';
  int _rpe = 5;
  bool _rpeSet = false;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _distance, _duration, _avgHr, _maxHr, _elevation, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now(),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    setState(() => _date = DateTime(d.year, d.month, d.day, t?.hour ?? _date.hour, t?.minute ?? _date.minute));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final km = double.tryParse(_distance.text.replaceAll(',', '.')) ?? 0;
    final body = <String, dynamic>{
      'title': _title.text.trim().isEmpty ? '${sportLabels[_sport]} manual' : _title.text.trim(),
      'sport': _sport,
      'sessionType': _type,
      'startDate': _date.toUtc().toIso8601String(),
      'distance': (km * 1000).round(),
      'movingTime': parseDurationInput(_duration.text),
      if (_avgHr.text.isNotEmpty) 'averageHeartRate': int.tryParse(_avgHr.text),
      if (_maxHr.text.isNotEmpty) 'maxHeartRate': int.tryParse(_maxHr.text),
      if (_elevation.text.isNotEmpty) 'elevationGain': int.tryParse(_elevation.text),
      if (_rpeSet) 'rpe': _rpe,
      'notes': _notes.text.trim(),
    };
    setState(() => _saving = true);
    final error = await context.read<TrainingProvider>().createSession(body);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppTheme.error));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesión registrada')));
    Navigator.pop(context);
  }

  InputDecoration _dec(String label, {String? hint, String? suffix}) => InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Colors.white);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar sesión'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(controller: _title, style: style, decoration: _dec('Título', hint: 'Ej: Series 6×1000')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _sport,
                    dropdownColor: AppTheme.surfaceAlt,
                    decoration: _dec('Deporte'),
                    style: style,
                    items: sportLabels.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setState(() => _sport = v ?? 'run'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _type,
                    dropdownColor: AppTheme.surfaceAlt,
                    decoration: _dec('Tipo'),
                    style: style,
                    items: sessionTypeLabels.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _type = v ?? 'auto'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event, color: AppTheme.primary),
              title: Text(
                '${formatShortDate(_date)} ${_date.year} · ${_date.hour.toString().padLeft(2, '0')}:${_date.minute.toString().padLeft(2, '0')}',
                style: style,
              ),
              trailing: const Icon(Icons.edit, color: AppTheme.grey, size: 18),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _distance,
                    style: style,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Distancia', suffix: 'km'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final n = double.tryParse(v.replaceAll(',', '.'));
                      return n == null || n < 0 || n > 400 ? 'Inválida' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _duration,
                    style: style,
                    keyboardType: TextInputType.datetime,
                    decoration: _dec('Duración', hint: 'h:mm:ss o mm:ss'),
                    validator: (v) {
                      final s = parseDurationInput(v ?? '');
                      return s == null || s <= 0 ? 'Requerida' : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _avgHr,
                    style: style,
                    keyboardType: TextInputType.number,
                    decoration: _dec('FC media', suffix: 'ppm'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _maxHr,
                    style: style,
                    keyboardType: TextInputType.number,
                    decoration: _dec('FC máx', suffix: 'ppm'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _elevation,
                    style: style,
                    keyboardType: TextInputType.number,
                    decoration: _dec('Desnivel', suffix: 'm'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Esfuerzo percibido (RPE)', style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
                const Spacer(),
                Text(_rpeSet ? '$_rpe / 10' : 'Sin anotar', style: AppTheme.titleMedium.copyWith(fontSize: 14)),
              ],
            ),
            Slider(
              value: _rpe.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_rpe',
              activeColor: _rpeSet ? AppTheme.secondary : AppTheme.darkGrey,
              onChanged: (v) => setState(() {
                _rpe = v.round();
                _rpeSet = true;
              }),
            ),
            Text('Sin pulsómetro, el RPE se usa para calcular la carga.', style: AppTheme.bodySmall),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notes,
              style: style,
              maxLines: 3,
              maxLength: 1000,
              decoration: _dec('Notas'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, minimumSize: const Size.fromHeight(50)),
              child: _saving ? const InlineSpinner() : const Text('Guardar sesión', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
