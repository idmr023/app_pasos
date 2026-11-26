import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/training.dart';
import '../../providers/auth_provider.dart';
import '../../providers/training_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/loading_states.dart';
import '../../widgets/strava_connect_dialog.dart';
import 'strava_import_screen.dart';
import 'training_log_screen.dart';
import 'training_profile_sheet.dart';
import 'training_session_screen.dart';
import 'training_widgets.dart';

/// Entrenamiento profesional: estado de forma (CTL/ATL/TSB, ACWR), volumen
/// semanal, nivel (VDOT, predicciones y ritmos), objetivo y plan de la próxima
/// semana. Sesiones importadas de Strava (a elección) o registradas a mano.
class TrainingHubScreen extends StatefulWidget {
  const TrainingHubScreen({super.key});

  @override
  State<TrainingHubScreen> createState() => _TrainingHubScreenState();
}

class _TrainingHubScreenState extends State<TrainingHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().token;
      if (token != null) context.read<TrainingProvider>().setToken(token);
    });
  }

  Future<void> _connectStrava() async {
    final connected = await StravaConnectDialog.show(context, onConnectedMessage: 'Strava conectado');
    if (!connected || !mounted) return;
    await context.read<AuthProvider>().refreshProfile();
    if (mounted) await context.read<TrainingProvider>().load();
  }

  void _openImport() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StravaImportScreen()));
  }

  void _openLog() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const TrainingLogScreen()));
  }

  void _openSession(TrainingSession s) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TrainingSessionScreen(sessionId: s.id)));
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TrainingProvider>();
    final summary = prov.summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenamiento'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Perfil y objetivo',
            icon: const Icon(Icons.tune),
            onPressed: () => TrainingProfileSheet.show(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openLog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.edit_note, color: Colors.white),
        label: const Text('Registrar', style: TextStyle(color: Colors.white)),
      ),
      body: Builder(builder: (context) {
        if (prov.isLoading && summary == null) return const AppLoading();
        if (prov.error != null && summary == null) {
          return ErrorState(message: prov.error!, onRetry: prov.load);
        }
        return RefreshIndicator(
          onRefresh: prov.load,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) prov.loadMoreSessions();
              return false;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _stravaCard(prov.hasStrava),
                if (summary != null && summary.totalSessions == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: EmptyStateCard(
                      icon: Icons.directions_run,
                      title: 'Aún no hay entrenamientos',
                      subtitle: 'Importa tus actividades de Strava o registra una sesión para ver tu análisis y tu plan.',
                    ),
                  ),
                if (summary != null) ...[
                  _recommendationCard(summary),
                  _loadCard(summary),
                  _weeklyChart(summary),
                  _fitnessCard(summary),
                  _goalCard(summary),
                  _intensityCard(summary),
                ],
                SectionTitle('Sesiones', trailing: Text('${prov.sessions.length}', style: AppTheme.bodySmall)),
                ...prov.sessions.map(_sessionTile),
                if (prov.loadingMore) const Padding(padding: EdgeInsets.all(16), child: AppLoading(size: 24)),
              ],
            ),
          ),
        );
      }),
    );
  }

  // --- Strava ---------------------------------------------------------------

  Widget _stravaCard(bool hasStrava) {
    return GlassCard(
      borderColor: stravaOrange,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: stravaOrange, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hasStrava ? 'Importar de Strava' : 'Conecta Strava', style: AppTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  hasStrava
                      ? 'Elige qué actividades analizar: splits, FC, vueltas y mejores esfuerzos.'
                      : 'Trae tus carreras con splits y frecuencia cardíaca para analizarlas.',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: hasStrava ? _openImport : _connectStrava,
            style: ElevatedButton.styleFrom(backgroundColor: stravaOrange),
            child: Text(hasStrava ? 'Elegir' : 'Conectar', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- Recomendación semanal ------------------------------------------------

  static const _modeLabels = {
    'build': ('Progresar', AppTheme.tertiary),
    'hold': ('Mantener', AppTheme.gold),
    'deload': ('Semana de descarga', Color(0xFF64B5F6)),
    'reduce': ('Reducir carga', AppTheme.error),
    'rebuild': ('Recuperar volumen', AppTheme.primary),
    'taper': ('Taper pre-carrera', Color(0xFF8B5CF6)),
    'start': ('Empezar', AppTheme.primary),
  };

  Widget _recommendationCard(TrainingSummary s) {
    final r = s.recommendation;
    final mode = r['mode']?.toString() ?? 'build';
    final (label, color) = _modeLabels[mode] ?? ('Plan', AppTheme.primary);
    final reasons = ((r['reasons'] as List?) ?? []).map((e) => e.toString()).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GlassCard(
        borderColor: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text('Próxima semana', style: AppTheme.titleMedium)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                  child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: StatCell(label: 'Volumen objetivo', value: '${r['targetKm'] ?? 0} km', color: color)),
                Expanded(child: StatCell(label: 'Semana pasada', value: '${r['lastWeekKm'] ?? 0} km')),
                Expanded(child: StatCell(label: 'Tirada máx.', value: '${r['longRunMaxKm'] ?? 0} km')),
              ],
            ),
            const SizedBox(height: 12),
            ...reasons.map((t) => InsightTile(TrainingInsight.fromJson({'level': 'info', 'text': t}))),
            if (s.plan.isNotEmpty) ...[
              const Divider(color: AppTheme.border, height: 24),
              Text('${s.plan.length} sesiones sugeridas', style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
              const SizedBox(height: 8),
              ...s.plan.map(_plannedTile),
            ],
          ],
        ),
      ),
    );
  }

  Widget _plannedTile(PlannedSession p) {
    final color = sessionTypeColor(p.type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 4, height: 44, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SessionTypeChip(p.type),
                    const SizedBox(width: 8),
                    Text('${p.distanceKm} km', style: AppTheme.titleMedium.copyWith(fontSize: 14)),
                    const Spacer(),
                    Flexible(child: Text(p.pace, style: AppTheme.bodySmall.copyWith(color: color), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(p.description, style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Carga / forma --------------------------------------------------------

  static const _statusLabels = {
    'optimal': ('Zona óptima', AppTheme.tertiary, 'Tu carga reciente está en el rango que mejora sin disparar el riesgo de lesión (0.8–1.3).'),
    'caution': ('Precaución', AppTheme.gold, 'Subiste carga rápido (1.3–1.5). Consolida antes de añadir más.'),
    'danger': ('Riesgo alto', AppTheme.error, 'Tu carga de la semana supera 1.5× lo habitual: el riesgo de lesión sube mucho.'),
    'detraining': ('Carga baja', Color(0xFF64B5F6), 'Entrenas menos de lo habitual: perderás forma si se mantiene.'),
    'building': ('Recopilando datos', AppTheme.grey, 'Con 3–4 semanas de sesiones el análisis de carga será fiable.'),
  };

  static const _formLabels = {
    'fresh': 'Fresco',
    'neutral': 'Neutral',
    'productive': 'Cargando',
    'overreached': 'Sobrecarga',
  };

  Widget _loadCard(TrainingSummary s) {
    final l = s.load;
    final status = l['status']?.toString() ?? 'building';
    final (label, color, desc) = _statusLabels[status] ?? _statusLabels['building']!;
    final acwr = l['acwr'];
    final tsb = (l['tsb'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_heart_outlined, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('Estado de forma', style: AppTheme.titleMedium)),
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: StatCell(label: 'Fitness (CTL)', value: '${l['ctl'] ?? 0}', hint: '42 días')),
                Expanded(child: StatCell(label: 'Fatiga (ATL)', value: '${l['atl'] ?? 0}', hint: '7 días')),
                Expanded(
                  child: StatCell(
                    label: 'Forma (TSB)',
                    value: tsb > 0 ? '+$tsb' : '$tsb',
                    hint: _formLabels[l['form']] ?? '',
                    color: tsb < -30 ? AppTheme.error : tsb > 5 ? AppTheme.tertiary : null,
                  ),
                ),
                Expanded(child: StatCell(label: 'Carga aguda', value: acwr == null ? '--' : '$acwr×', hint: 'ACWR', color: color)),
              ],
            ),
            const SizedBox(height: 10),
            Text(desc, style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
            if (s.heartRate['maxSource'] == 'unknown')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Configura tu FC máxima (⚙) para zonas y carga precisas.',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.gold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _weeklyChart(TrainingSummary s) {
    final weeks = s.weeks;
    if (weeks.isEmpty) return const SizedBox.shrink();
    final maxKm = weeks.fold<double>(0, (m, w) => w.distanceKm > m ? w.distanceKm : m);
    final target = (s.recommendation['targetKm'] as num?)?.toDouble() ?? 0;
    final top = [maxKm, target, 5.0].reduce((a, b) => a > b ? a : b) * 1.2;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Volumen semanal (km de carrera)', style: AppTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Línea punteada: objetivo de la próxima semana', style: AppTheme.bodySmall),
            const SizedBox(height: 16),
            SizedBox(
              height: 170,
              child: BarChart(
                BarChartData(
                  maxY: top,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    if (target > 0)
                      HorizontalLine(y: target, color: AppTheme.tertiary.withValues(alpha: 0.7), strokeWidth: 1.5, dashArray: [6, 4]),
                  ]),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppTheme.surfaceAlt,
                      getTooltipItem: (group, _, rod, __) {
                        final w = weeks[group.x];
                        return BarTooltipItem(
                          '${formatShortDate(w.weekStart)}\n${w.distanceKm} km · ${w.sessions} ses.',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= weeks.length || (i % 2 != weeks.length % 2 && !weeks[i].current)) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              weeks[i].current ? 'Hoy' : '${weeks[i].weekStart.day}/${weeks[i].weekStart.month}',
                              style: const TextStyle(color: AppTheme.darkGrey, fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(weeks.length, (i) {
                    final w = weeks[i];
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: w.distanceKm,
                        width: 14,
                        color: w.current ? AppTheme.secondary : AppTheme.primary,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ]);
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Nivel ----------------------------------------------------------------

  Widget _fitnessCard(TrainingSummary s) {
    final f = s.fitness;
    if (f == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: GlassCard(
          child: Text(
            'Nivel (VDOT): necesitamos al menos una carrera de 3 km o más en los últimos 90 días.',
            style: AppTheme.bodyMedium,
          ),
        ),
      );
    }
    final paces = (f['paces'] as Map?) ?? {};
    final easy = (paces['easy'] as Map?) ?? {};
    final predictions = (f['predictions'] as List?) ?? [];
    final basedOn = (f['basedOn'] as Map?) ?? {};
    final basedDate = DateTime.tryParse(basedOn['date']?.toString() ?? '');

    Widget paceRow(String name, String desc, String value, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              SizedBox(width: 120, child: Text(name, style: AppTheme.bodyMedium.copyWith(color: AppTheme.white))),
              Expanded(child: Text(desc, style: AppTheme.bodySmall)),
              Text(value, style: AppTheme.bodyMedium.copyWith(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed, color: AppTheme.gold),
                const SizedBox(width: 8),
                Expanded(child: Text('Tu nivel', style: AppTheme.titleMedium)),
                Text('VDOT ${f['vdot']}', style: AppTheme.titleLarge.copyWith(color: AppTheme.gold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Basado en: ${basedOn['effort'] ?? ''} · ${basedOn['title'] ?? ''}${basedDate != null ? ' (${formatShortDate(basedDate.toLocal())})' : ''}',
              style: AppTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Row(
              children: predictions.map((p) {
                final m = p as Map;
                return Expanded(child: StatCell(label: m['label'].toString(), value: formatDuration(m['timeSec'] as num?)));
              }).toList(),
            ),
            const Divider(color: AppTheme.border, height: 24),
            Text('Ritmos de entrenamiento', style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
            const SizedBox(height: 6),
            paceRow('Suave (E)', 'Rodajes y tiradas', '${formatPace(easy['from'] as num?)}–${formatPace(easy['to'] as num?)}', AppTheme.tertiary),
            paceRow('Maratón (M)', 'Ritmo sostenido', formatPace(paces['marathon'] as num?), const Color(0xFF8B5CF6)),
            paceRow('Umbral (T)', 'Tempo 20–40 min', formatPace(paces['threshold'] as num?), AppTheme.gold),
            paceRow('Intervalos (I)', 'Series 3–5 min', formatPace(paces['interval'] as num?), AppTheme.secondary),
            paceRow('Repeticiones (R)', 'Series cortas 200–400 m', formatPace(paces['repetition'] as num?), AppTheme.error),
          ],
        ),
      ),
    );
  }

  static const _goalStatus = {
    'on_track': ('Vas en camino', AppTheme.tertiary),
    'achievable': ('Alcanzable', AppTheme.tertiary),
    'ambitious': ('Ambicioso', AppTheme.gold),
    'unrealistic': ('Poco realista', AppTheme.error),
    'behind': ('No alcanzado', AppTheme.error),
    'no_data': ('Faltan datos', AppTheme.grey),
    'no_target': ('Sin marca objetivo', AppTheme.grey),
  };

  static const _phaseLabels = {
    'base': 'Fase: base aeróbica',
    'build': 'Fase: construcción',
    'peak': 'Fase: específica',
    'taper': 'Fase: taper',
    'done': 'Fecha pasada',
  };

  Widget _goalCard(TrainingSummary s) {
    final g = s.goal;
    if (g == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: GlassCard(
          onTap: () => TrainingProfileSheet.show(context),
          child: Row(
            children: [
              const Icon(Icons.flag_outlined, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text('Define un objetivo (10K, media maratón…) para ver si vas en camino.', style: AppTheme.bodyMedium)),
              const Icon(Icons.chevron_right, color: AppTheme.grey),
            ],
          ),
        ),
      );
    }
    final (label, color) = _goalStatus[g['status']] ?? ('', AppTheme.grey);
    final weeksLeft = g['weeksLeft'];
    final predicted = g['predictedTimeSec'] as num?;
    final target = g['targetTimeSec'] as num?;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GlassCard(
        borderColor: color,
        onTap: () => TrainingProfileSheet.show(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(g['name']?.toString() ?? 'Objetivo', style: AppTheme.titleMedium)),
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: StatCell(label: 'Objetivo', value: formatDuration(target))),
                Expanded(child: StatCell(label: 'Predicción hoy', value: formatDuration(predicted), color: color)),
                Expanded(child: StatCell(label: 'Semanas', value: weeksLeft == null ? '--' : '$weeksLeft')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                if (_phaseLabels[g['phase']] != null) _phaseLabels[g['phase']]!,
                if (g['vdotGap'] != null && (g['vdotGap'] as num) > 0) 'Te faltan ${g['vdotGap']} puntos de VDOT',
              ].join(' · '),
              style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _intensityCard(TrainingSummary s) {
    final i = s.intensity;
    final e = s.efficiency;
    if (i == null && e == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calidad del entrenamiento (28 días)', style: AppTheme.titleMedium),
            if (i != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    Expanded(flex: (i['low'] as num).toInt().clamp(1, 100), child: Container(height: 14, color: AppTheme.tertiary)),
                    Expanded(flex: (i['moderate'] as num).toInt().clamp(1, 100), child: Container(height: 14, color: AppTheme.gold)),
                    Expanded(flex: (i['high'] as num).toInt().clamp(1, 100), child: Container(height: 14, color: AppTheme.error)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text('Suave ${i['low']}% · Moderado ${i['moderate']}% · Intenso ${i['high']}%  (meta ≈ 80/20)',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
            ],
            if (e != null) ...[
              const SizedBox(height: 12),
              InsightTile(TrainingInsight.fromJson({
                'level': (e['changePct'] as num) >= 0 ? 'good' : 'warn',
                'text': (e['changePct'] as num) >= 0
                    ? 'Eficiencia aeróbica +${e['changePct']}% en las últimas 3 semanas: corres más rápido a la misma FC.'
                    : 'Eficiencia aeróbica ${e['changePct']}% vs semanas previas: posible fatiga, calor o pérdida de forma.',
              })),
            ],
          ],
        ),
      ),
    );
  }

  // --- Lista de sesiones ----------------------------------------------------

  Widget _sessionTile(TrainingSession s) {
    final a = s.analysis;
    final isDistanceSport = s.distance > 0;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: () => _openSession(s),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: sessionTypeColor(s.effectiveType).withValues(alpha: 0.18),
            child: Icon(sportIcon(s.sport), color: sessionTypeColor(s.effectiveType)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(s.title, style: AppTheme.titleMedium.copyWith(fontSize: 14), overflow: TextOverflow.ellipsis)),
                    if (s.source == 'strava') const Icon(Icons.bolt, color: stravaOrange, size: 16),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    formatShortDate(s.startDate),
                    if (isDistanceSport) '${s.distanceKm.toStringAsFixed(1)} km',
                    formatDuration(s.movingTime),
                    if (isDistanceSport && a != null) formatPace(a.pace),
                    if (s.averageHeartRate > 0) '${s.averageHeartRate} ppm',
                  ].join(' · '),
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    SessionTypeChip(s.effectiveType),
                    const SizedBox(width: 8),
                    if (a != null) Text('Carga ${a.load.round()}', style: AppTheme.bodySmall),
                    if (s.rpe != null) Text(' · RPE ${s.rpe}', style: AppTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
