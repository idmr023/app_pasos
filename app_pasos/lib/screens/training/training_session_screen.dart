import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/training.dart';
import '../../providers/training_provider.dart';
import '../../widgets/error_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/loading_states.dart';
import 'training_widgets.dart';

/// Detalle de una sesión: métricas, análisis (splits, zonas, desacople,
/// comparación con la sesión similar anterior) y anotaciones del atleta
/// (tipo, RPE, sensación, notas).
class TrainingSessionScreen extends StatefulWidget {
  final String sessionId;
  const TrainingSessionScreen({super.key, required this.sessionId});

  @override
  State<TrainingSessionScreen> createState() => _TrainingSessionScreenState();
}

class _TrainingSessionScreenState extends State<TrainingSessionScreen> {
  TrainingSession? _session;
  String? _error;
  bool _saving = false;

  String _type = 'auto';
  int? _rpe;
  int? _feeling;
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final svc = context.read<TrainingProvider>().service;
    if (svc == null) return;
    setState(() => _error = null);
    try {
      final s = await svc.getSession(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _session = s;
        _type = s.sessionType;
        _rpe = s.rpe;
        _feeling = s.feeling;
        _notes.text = s.notes;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final error = await context.read<TrainingProvider>().updateSession(widget.sessionId, {
      'sessionType': _type,
      'rpe': _rpe,
      'feeling': _feeling,
      'notes': _notes.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppTheme.error));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesión guardada y reanalizada')));
    await _load();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Eliminar sesión'),
        content: const Text('Se borrará del módulo Entrenamiento (no de Strava).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final error = await context.read<TrainingProvider>().deleteSession(widget.sessionId);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppTheme.error));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    return Scaffold(
      appBar: AppBar(
        title: Text(s?.title ?? 'Sesión', overflow: TextOverflow.ellipsis),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.white,
        elevation: 0,
        actions: [
          if (s != null) IconButton(tooltip: 'Eliminar', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Builder(builder: (context) {
        if (_error != null && s == null) return ErrorState(message: _error!, onRetry: _load);
        if (s == null) return const AppLoading();
        final a = s.analysis;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _header(s),
              if (a != null && a.insights.isNotEmpty) ...[
                const SectionTitle('Análisis'),
                GlassCard(child: Column(children: a.insights.map(InsightTile.new).toList())),
              ],
              if (a?.splits != null) _splitSummary(a!.splits!),
              if (s.splits.length >= 2) _splitsChart(s),
              if (s.laps.length >= 2) _laps(s),
              if (a?.zonePercent != null) ...[
                const SectionTitle('Zonas de frecuencia cardíaca'),
                GlassCard(child: ZoneBars(a!.zonePercent!)),
              ],
              _annotations(),
            ],
          ),
        );
      }),
    );
  }

  Widget _header(TrainingSession s) {
    final a = s.analysis;
    final hasDistance = s.distance > 0;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(sportIcon(s.sport), color: sessionTypeColor(s.effectiveType)),
              const SizedBox(width: 8),
              Text(
                '${sportLabels[s.sport] ?? s.sport} · ${formatShortDate(s.startDate)} ${s.startDate.year}',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
              ),
              const Spacer(),
              SessionTypeChip(s.effectiveType),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (hasDistance) Expanded(child: StatCell(label: 'Distancia', value: '${s.distanceKm.toStringAsFixed(2)} km')),
              Expanded(child: StatCell(label: 'Tiempo', value: formatDuration(s.movingTime))),
              if (hasDistance) Expanded(child: StatCell(label: 'Ritmo', value: formatPace(a?.pace))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatCell(
                  label: 'FC media',
                  value: s.averageHeartRate > 0 ? '${s.averageHeartRate}' : '--',
                  hint: a?.hrPercentMax != null ? '${(a!.hrPercentMax! * 100).round()}% máx' : null,
                ),
              ),
              Expanded(child: StatCell(label: 'Desnivel', value: '${s.elevationGain} m')),
              Expanded(
                child: StatCell(
                  label: 'Carga',
                  value: a != null ? '${a.load.round()}' : '--',
                  hint: switch (a?.loadSource) {
                    'hr' => 'por FC',
                    'rpe' => 'por RPE',
                    'estimated' => 'estimada',
                    _ => null,
                  },
                ),
              ),
            ],
          ),
          if (s.averageCadence > 0 || a?.efficiency != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (s.averageCadence > 0) Expanded(child: StatCell(label: 'Cadencia', value: '${s.averageCadence} ppm')),
                if (a?.efficiency != null)
                  Expanded(child: StatCell(label: 'Eficiencia', value: a!.efficiency!.toStringAsFixed(2), hint: 'm/min por latido')),
                if (s.maxHeartRate > 0) Expanded(child: StatCell(label: 'FC máx', value: '${s.maxHeartRate}')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _splitSummary(Map<String, dynamic> sp) {
    final type = sp['splitType'];
    final label = type == 'negative' ? 'Negativo' : type == 'positive' ? 'Positivo' : 'Parejo';
    final cv = ((sp['paceCv'] as num?) ?? 0) * 100;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GlassCard(
        child: Row(
          children: [
            Expanded(child: StatCell(label: '1ª mitad', value: formatPace(sp['firstHalfPace'] as num?))),
            Expanded(child: StatCell(label: '2ª mitad', value: formatPace(sp['secondHalfPace'] as num?))),
            Expanded(
              child: StatCell(
                label: 'Split',
                value: label,
                hint: 'variación ${cv.toStringAsFixed(1)}%',
                color: type == 'negative' ? AppTheme.tertiary : type == 'positive' ? AppTheme.gold : null,
              ),
            ),
            if (sp['decouplingPct'] != null)
              Expanded(child: StatCell(label: 'Desacople', value: '${sp['decouplingPct']}%')),
          ],
        ),
      ),
    );
  }

  Widget _splitsChart(TrainingSession s) {
    final splits = s.splits.where((x) => x.distance >= 300 && x.movingTime > 0).toList();
    if (splits.length < 2) return const SizedBox.shrink();
    final paces = splits.map((x) => x.pace).toList();
    final slowest = paces.reduce((a, b) => a > b ? a : b);
    final fastest = paces.reduce((a, b) => a < b ? a : b);
    final avg = paces.reduce((a, b) => a + b) / paces.length;
    // Barra más alta = km más rápido: se grafica (slowest + margen − ritmo).
    final floor = slowest + 15;
    final range = floor - fastest + 15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Splits por km'),
        GlassCard(
          child: Column(
            children: [
              SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    maxY: range,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 20,
                          getTitlesWidget: (v, meta) {
                            final i = v.toInt();
                            if (i < 0 || i >= splits.length) return const SizedBox.shrink();
                            if (splits.length > 15 && i % 2 == 1) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('${splits[i].index}', style: const TextStyle(color: AppTheme.darkGrey, fontSize: 10)),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => AppTheme.surfaceAlt,
                        getTooltipItem: (group, _, __, ___) {
                          final sp = splits[group.x];
                          return BarTooltipItem(
                            'Km ${sp.index}\n${formatPace(sp.pace)}${sp.averageHeartRate > 0 ? '\n${sp.averageHeartRate} ppm' : ''}',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        },
                      ),
                    ),
                    barGroups: List.generate(splits.length, (i) {
                      final p = paces[i];
                      return BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: floor - p,
                          width: splits.length > 20 ? 6 : 12,
                          color: p <= avg ? AppTheme.tertiary : AppTheme.primary,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ]);
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('Verde = más rápido que tu media (${formatPace(avg)})', style: AppTheme.bodySmall),
              const Divider(color: AppTheme.border, height: 20),
              ...splits.map((sp) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(width: 40, child: Text('${sp.index}', style: AppTheme.bodySmall.copyWith(color: AppTheme.grey))),
                        Expanded(child: Text(formatPace(sp.pace), style: AppTheme.bodyMedium.copyWith(color: AppTheme.white))),
                        SizedBox(
                          width: 70,
                          child: Text(sp.averageHeartRate > 0 ? '${sp.averageHeartRate} ppm' : '', style: AppTheme.bodySmall),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(
                            '${sp.elevationDiff >= 0 ? '+' : ''}${sp.elevationDiff.round()} m',
                            textAlign: TextAlign.right,
                            style: AppTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _laps(TrainingSession s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Vueltas'),
        GlassCard(
          child: Column(
            children: s.laps.map((l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(width: 40, child: Text('${l.index}', style: AppTheme.bodySmall.copyWith(color: AppTheme.grey))),
                      Expanded(child: Text('${(l.distance / 1000).toStringAsFixed(2)} km', style: AppTheme.bodyMedium.copyWith(color: AppTheme.white))),
                      SizedBox(width: 64, child: Text(formatDuration(l.movingTime), style: AppTheme.bodySmall)),
                      SizedBox(width: 80, child: Text(formatPace(l.pace), textAlign: TextAlign.right, style: AppTheme.bodySmall.copyWith(color: AppTheme.white))),
                      SizedBox(width: 60, child: Text(l.averageHeartRate > 0 ? '${l.averageHeartRate}' : '', textAlign: TextAlign.right, style: AppTheme.bodySmall)),
                    ],
                  ),
                )).toList(),
          ),
        ),
      ],
    );
  }

  static const _feelings = ['😫', '😕', '😐', '🙂', '🤩'];

  Widget _annotations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Tus datos de la sesión'),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tipo de sesión', style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: sessionTypeLabels.entries.map((e) {
                  final selected = _type == e.key;
                  final color = sessionTypeColor(e.key);
                  return ChoiceChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) => setState(() => _type = e.key),
                    selectedColor: color.withValues(alpha: 0.25),
                    labelStyle: TextStyle(color: selected ? color : AppTheme.grey, fontSize: 12),
                    backgroundColor: AppTheme.surfaceAlt,
                    side: BorderSide(color: selected ? color : AppTheme.border),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Esfuerzo percibido (RPE)', style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
                  const Spacer(),
                  Text(_rpe == null ? 'Sin anotar' : '$_rpe / 10', style: AppTheme.titleMedium.copyWith(fontSize: 14)),
                ],
              ),
              Slider(
                value: (_rpe ?? 5).toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: _rpe == null ? AppTheme.darkGrey : AppTheme.secondary,
                label: '${_rpe ?? 5}',
                onChanged: (v) => setState(() => _rpe = v.round()),
              ),
              Text('1–3 muy fácil · 4–6 moderado · 7–8 duro · 9–10 máximo', style: AppTheme.bodySmall),
              const SizedBox(height: 16),
              Text('¿Cómo te sentiste?', style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(5, (i) {
                  final selected = _feeling == i + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _feeling = selected ? null : i + 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primary.withValues(alpha: 0.25) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_feelings[i], style: TextStyle(fontSize: selected ? 30 : 24)),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notes,
                maxLines: 4,
                maxLength: 1000,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Notas (sueño, molestias, clima, sensaciones…)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving ? const InlineSpinner(size: 16) : const Icon(Icons.save, color: Colors.white),
                  label: const Text('Guardar y reanalizar', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, minimumSize: const Size.fromHeight(46)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
